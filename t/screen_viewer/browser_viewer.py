# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright 2026 City of Clinton, Iowa
"""Exercise the real viewer UI with synthetic API/RFB fixtures; no desktop access."""
import argparse, asyncio, re
from pathlib import Path
from playwright.async_api import async_playwright

async def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("server_checkout",type=Path)
    parser.add_argument("assets",type=Path,help="jquery.js, bootstrap.js, bootstrap-4.0.0.min.css")
    parser.add_argument("--screenshot",type=Path)
    args=parser.parse_args()
    template=(args.server_checkout/"root/dynamic/templates/administration/index.tt").read_text()
    start=template.index('[% IF ScreenViewerEnabled %]')
    modal=template[start:template.index('<script type="text/javascript">',start)]
    modal=re.sub(r"\[%.*?%\]","",modal,flags=re.S)
    start=template.index('    let screenViewerGeneration')
    js=template[start:template.index('    /* Modify Time */',start)]
    js=re.sub(r"\[% c.uri_for\('/administration/api/screenviewer/token'\) %\]","/token",js)
    setup="""
const screenViewerClients = new Set(['DEMO-PC-01','DEMO-PC-02']);
let activeScreenViewer=null, pendingScreenViewerClient=null;
function DisplayMessage(type,text) { throw new Error(text); }
window.testState={connections:[], delay:0};
"""
    rfb="""
export default class RFB {
 constructor(canvas,url,options) {
  this.url=url;this.options=options;this.handlers={};
  window.testState.connections.push(this);
 }
 addEventListener(name,handler){this.handlers[name]=handler;}
 disconnect(){this.disconnected=true;if(this.handlers.disconnect)this.handlers.disconnect({detail:{clean:true}});}
}
"""
    html="""<!doctype html><html><head><meta charset="utf-8"><link rel="stylesheet" href="/assets/bootstrap-4.0.0.min.css"></head><body style="background:#f3f4f6">
<header class="p-3 bg-dark text-white">Libki · Staff administration <span class="float-right">Demonstration data</span></header>
<main class="p-4"><h2>Workstations</h2><p>Choose a workstation to request screen-viewing permission.</p>
<table class="table bg-white" id="client-table"><thead><tr><th>Computer</th><th>Status</th><th>Staff tools</th></tr></thead><tbody>
<tr><td>DEMO-PC-01</td><td>In use</td><td><button class="client-screen-viewer btn btn-info" data-clientname="DEMO-PC-01">View screen</button></td></tr>
<tr><td>DEMO-PC-02</td><td>In use</td><td><button class="client-screen-viewer btn btn-info" data-clientname="DEMO-PC-02">View screen</button></td></tr></tbody></table>
</main>"""+modal+"""<script src="/assets/jquery.js"></script><script src="/assets/bootstrap.js"></script><script>$(function(){"""+setup+js+"""});</script></body></html>"""
    async with async_playwright() as play:
        browser=await play.chromium.launch(headless=True,args=["--no-sandbox"])
        page=await browser.new_page(viewport={"width":1440,"height":1000})
        failures=[]
        page.on("pageerror",lambda e:failures.append(str(e)))
        async def route(request):
            path=request.request.url.split("example.org",1)[1].split("?",1)[0]
            if path=="/": await request.fulfill(body=html,content_type="text/html")
            elif path.startswith("/assets/"):
                f=args.assets/path.rsplit("/",1)[1]
                await request.fulfill(body=f.read_bytes(),content_type="text/css" if f.suffix==".css" else "text/javascript")
            elif path=="/token":
                delay=await page.evaluate("testState.delay")
                await asyncio.sleep(delay)
                await request.fulfill(json={"token":"fixture-token","vnc_password":"fixture","mode":"view-only"})
            elif path=="/static/vendor/novnc/core/rfb.js":
                delay=await page.evaluate("testState.importDelay || 0")
                await page.evaluate("testState.importStarted = true")
                await asyncio.sleep(delay)
                await request.fulfill(body=rfb,content_type="text/javascript")
            elif path.startswith("/actual-novnc/"):
                f=args.server_checkout/"root/static/vendor/novnc"/path[len("/actual-novnc/"):]
                await request.fulfill(body=f.read_bytes(),content_type="text/javascript")
            else: await request.abort()
        await page.route("**/*",route)
        await page.goto("https://libki.example.org/")
        # The complete pinned noVNC module must really load, independently of fixture RFB.
        assert await page.evaluate("async()=>typeof (await import('/actual-novnc/core/rfb.js')).default==='function'")
        async def open_client(name):
            await page.evaluate("window.modalReady=false; $('#screen-viewer-modal').one('shown.bs.modal',()=>window.modalReady=true)")
            await page.locator(f'[data-clientname="{name}"]').click()
            await page.locator("#screen-viewer-reason").select_option("patron_assistance")
            await page.wait_for_function("window.modalReady === true")
        async def request_view():
            await page.locator("#screen-viewer-request-button").click()
        async def close_view():
            await page.get_by_role("button",name="Close viewer",exact=True).click()
            await page.locator("#screen-viewer-modal").wait_for(state="hidden")
        await open_client("DEMO-PC-01")
        if args.screenshot:
            args.screenshot.parent.mkdir(parents=True,exist_ok=True)
            await page.locator("#screen-viewer-modal .modal-content").screenshot(path=str(args.screenshot))
        await request_view()
        await page.wait_for_function("testState.connections.length===1")
        assert await page.evaluate("testState.connections[0].viewOnly === true")
        await close_view()
        assert await page.evaluate("testState.connections[0].disconnected")
        # Close with an outstanding token request must never create a hidden RFB.
        await page.evaluate("testState.delay=.4")
        await open_client("DEMO-PC-01");await request_view();await close_view()
        await page.wait_for_timeout(600)
        assert await page.evaluate("testState.connections.length===1")
        # Open another workstation while the previous request completes.
        await open_client("DEMO-PC-01");await request_view();await close_view()
        await page.evaluate("testState.delay=0")
        await open_client("DEMO-PC-02");await request_view()
        await page.wait_for_function("testState.connections.length===2")
        await page.wait_for_timeout(600)
        assert await page.evaluate("testState.connections.length===2")
        await close_view()
        # A fresh document has no cached RFB module: close during its import.
        await page.reload()
        await page.evaluate("testState.importDelay=.4")
        await open_client("DEMO-PC-01");await request_view()
        await page.wait_for_function("testState.importStarted === true")
        await close_view()
        await page.wait_for_timeout(600)
        assert await page.evaluate("testState.connections.length===0")
        assert not failures,failures
        await browser.close()
        print("Browser checks passed: complete noVNC import, view-only flag, close/disconnect, pending close, workstation switch.")

asyncio.run(main())
