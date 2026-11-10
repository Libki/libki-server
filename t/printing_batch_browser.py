"""Print selection: shipped DataTables/template code, synthetic HTTP only.
Run in simon/browser-admin with --network none; never contacts production/CUPS.
"""
import asyncio,json,re,os
from pathlib import Path
from urllib.parse import urlparse,parse_qs
from playwright.async_api import async_playwright

async def main():
    source=Path('/work/root/dynamic/templates/administration/index.tt').read_text()
    def expand(js):
        js=re.sub(r"\[% IF !c.language.match\('en'\) %\].*?\[% END %\]",'',js,flags=re.S)
        js=re.sub(r"\[% c.uri_for\([\"']([^\"']+)[\"']\) %\]",lambda m:'/administration/'+m[1] if not m[1].startswith('/') else m[1],js)
        return re.sub(r"\[% c.loc\([\"']([^\"']+)[\"']\) %\]",lambda m:m[1],js)
    start=source.index('    const selectedPrintJobs = new Set();')
    queue=expand(source[start:source.index('    /*********** Page Wide Actions',start)])
    start=source.index("    $('#print-table').on('click', '.print-select'")
    review=expand(source[start:source.index('    /* Refresh Print Job */',start)])
    start=source.index('<table id="print-table"')
    table=expand(source[start:source.index('</table>',start)+8])
    mainjs=Path('/work/root/static/js/main.js').read_text()
    start=mainjs.index('function AddTableRowToolbar(')
    toolbar=mainjs[start:mainjs.index('\n}\n',start)+3]
    fixtures={}
    for n in range(1,22):
        route=['Main - B&W','Main - Color','Genealogy - B&W','Genealogy - Color'][(n-1)%4]
        fixtures[str(n)]={'filename':f'Document {n}.pdf','printer_name':route,
            'pages':1 if n in [1,4] else 2,'copies':2 if n==4 else 1,
            'library_card':'synthetic-patron','identifier_label':'Patron',
            'status':'Held','rate':.35 if 'Color' in route else .15}
    fixtures['90']={**fixtures['1'],'status':'Done'}
    fixtures['91']={**fixtures['1'],'status':'Pending'}
    state={'visible':['1','2','3','4','90','91'],'quote_failure':None,
           'outcomes':{},'delay':False}
    posts=[];errors=[];messages=[];in_flight=0;max_in_flight=0
    async with async_playwright() as p:
        browser=await p.chromium.launch(headless=True,args=['--no-sandbox'])
        page=await browser.new_page(viewport={'width':1366,'height':900})
        page.set_default_timeout(7000)
        page.on('pageerror',lambda e:errors.append(str(e)))
        async def route(r):
            nonlocal in_flight,max_in_flight
            q=parse_qs(urlparse(r.request.url).query)
            if '/datatables/prints' in r.request.url:
                data=[]
                for id in state['visible']:
                    f=fixtures[id]
                    data.append({'0':'cups','1':f['status'],'2':f['printer_name'],
                        '3':f['copies'],'4':f['filename'],'5':f['pages'],'6':'SYNTHETIC-PC',
                        '7':f['library_card'],'8':'2026-10-30T12:00:00','DT_RowId':id})
                return await r.fulfill(json={'draw':int(q.get('draw',['1'])[0]),
                    'recordsTotal':len(data),'recordsFiltered':len(data),'data':data})
            if '/preview' in r.request.url:
                id=q['id'][0]; f=fixtures[id]
                if state['delay'] and id=='1': await asyncio.sleep(.25)
                if state['quote_failure']==id:
                    return await r.fulfill(status=503,body='Synthetic failure')
                count=int(q.get('copies',[str(f['copies'])])[0])
                return await r.fulfill(json={'success':1,
                    'action_mode':'reprint' if f['status']=='Done' else ('release' if f['status']=='Held' else 'none'),
                    **{k:f[k] for k in ['filename','printer_name','pages','library_card','identifier_label']},
                    'copies':count,'total_pages':f['pages']*count,
                    'amount_due':f"{f['pages']*count*f['rate']:.2f}"})
            if r.request.method=='POST':
                assert '/release' in r.request.url or '/reprint' in r.request.url
                body={k:v[0] for k,v in parse_qs(r.request.post_data).items()}
                posts.append({'url':r.request.url,**body})
                in_flight+=1;max_in_flight=max(max_in_flight,in_flight)
                await asyncio.sleep(.08)
                in_flight-=1
                result=state['outcomes'].get(body['id'],'accept')
                if result=='network': return await r.abort()
                if result=='expired': return await r.fulfill(status=401,json={'success':0})
                if result=='fail': return await r.fulfill(json={'success':0,'safe_to_retry':1,'error':'SYNTHETIC_SAFE_FAILURE'})
                if result=='uncertain': return await r.fulfill(json={'success':0,'safe_to_retry':0,'manual_review':1,'error':'SYNTHETIC_UNKNOWN'})
                return await r.fulfill(json={'success':1})
            if r.request.url=='https://print-stage.test/':
                return await r.fulfill(content_type='text/html',body='<html><body>'+
                    table+'<div id="print-table-row-toolbar"><button id="print-table-row-toolbar-release" hidden>Reprint</button></div></body></html>')
            return await r.abort()
        await page.route('**/*',route)
        await page.goto('https://print-stage.test/')
        for asset in ['jquery.js','bootstrap.js','datatables.js','datatables-bootstrap.js']:
            await page.add_script_tag(content=Path('/assets/'+asset).read_text())
        await page.add_script_tag(content=toolbar+"""
            const testMessages=[];
            function DisplayMessage(type,text){testMessages.push(text);}
            function ForcePrintTableRefresh(){pTable.ajax.reload(null,false);}
        """+queue+review)
        await page.wait_for_selector('.print-select')
        button=page.locator('#print-selected-button')
        assert await button.is_disabled()
        assert await page.locator('#print-table thead th').first.inner_text()=='Select'
        assert 'cups' not in await page.locator('#print-table tbody').inner_text()
        assert await page.locator('.print-select').count()==4
        assert await page.get_by_role('button',name='Release selected',exact=True).count()==0
        async def select(*ids):
            for id in ids: await page.locator(f'.print-select[data-print-id="{id}"]').check()
        async def close():
            await page.locator('.print-close').click()
            await page.wait_for_selector('#staff-print-review',state='detached')
        async def total(amount):
            await page.wait_for_function("(v)=>document.querySelector('.print-total').textContent.includes(v)",arg=amount)
        async def reload():
            await page.evaluate("ForcePrintTableRefresh()")
            await page.wait_for_timeout(180)
        await select('1','4')
        assert await button.inner_text()=='Print selected (2)'
        await button.click(); await total('$0.85')
        assert await page.locator('.print-copies').evaluate_all('(els)=>els.map(el=>el.value)')==['1','2']
        assert await page.locator('.print-printer').all_text_contents()==['Main - B&W','Genealogy - Color']
        await page.locator('.print-copies').nth(1).fill('5')
        await total('$1.90')
        assert 'Total printed pages: 6' in await page.locator('.print-total').inner_text()
        assert await page.locator('.print-line-total').all_text_contents()==['$0.15','$1.75']
        assert await page.locator('.print-submit').is_disabled()
        await page.locator('.print-cash').check()
        assert await page.locator('.print-submit').is_enabled()
        await page.locator('.print-copies').first.fill('16')
        await total('$4.15')
        assert not await page.locator('.print-cash').is_checked()
        for bad in ['0','100','1.5','']:
            await page.locator('.print-copies').first.fill(bad)
            assert await page.locator('.print-submit').is_disabled()
            assert await page.locator('.print-cash').is_disabled()
        await page.locator('.print-copies').first.fill('99')
        await total('$16.60')
        await close()
        assert not posts
        # Selection retained on same-page refresh, removed if hidden/non-held.
        await reload()
        assert await button.inner_text()=='Print selected (2)'
        state['visible']=['2','3','90','91']; await reload()
        assert await button.inner_text()=='Print selected (0)'
        assert await button.is_disabled()
        await select('2')
        fixtures['2']['status']='Pending';await reload()
        assert await button.is_disabled()
        fixtures['2']['status']='Held'
        state['visible']=['1','2','3','4','90','91'];await reload()
        # History reprint remains available only on completed row hover.
        await page.locator('tr[id="1"]').hover()
        assert await page.locator('#print-table-row-toolbar-release').is_hidden()
        await page.locator('tr[id="90"]').hover()
        await page.locator('#print-table-row-toolbar-release').click()
        await total('$0.15')
        assert 'Additional reprint' in await page.locator('.print-total').inner_text()
        assert await page.locator('.print-submit').inner_text()=='Reprint document'
        await close()
        # 20-job cap both in checkbox interaction and direct review entry.
        state['visible']=[str(n) for n in range(1,22)];await reload()
        await page.evaluate("pTable.page.len(100).draw()")
        await page.wait_for_timeout(180)
        await select(*[str(n) for n in range(1,21)])
        await page.locator('.print-select[data-print-id="21"]').click()
        assert not await page.locator('.print-select[data-print-id="21"]').is_checked()
        assert await button.inner_text()=='Print selected (20)'
        await button.click();await page.wait_for_function("document.querySelectorAll('.print-line-total').length===20 && !document.querySelector('.print-cash').disabled")
        assert await page.locator('.print-copies').count()==20
        await close()
        await page.evaluate("openPrintReview(Array.from({length:21},(_,i)=>String(i+1)),true)")
        assert await page.locator('#staff-print-review').count()==0
        # Queue switch clears selection even when rows still held.
        await page.locator('select[aria-label="Print queue view"]').select_option('all')
        await page.wait_for_timeout(180)
        assert await button.is_disabled()
        # Mixed four-route totals: 0.15 + 0.70 + 0.30 + 0.70 = 1.85.
        state['visible']=['1','2','3','4'];await reload()
        await select('1','2','3','4')
        state['quote_failure']='3'
        await button.click()
        await page.wait_for_function("document.querySelector('.print-total').textContent.includes('Total unavailable')")
        assert await page.locator('.print-cash').is_disabled()
        assert await page.locator('.print-submit').is_disabled()
        await close()
        state['quote_failure']=None;state['delay']=True
        await button.click();await total('$1.85')
        state['delay']=False
        # Only synthetic intercepted POSTs: sequential, partial outcomes and double click.
        state['outcomes']={'2':'fail','3':'uncertain','4':'network'}
        await page.locator('.print-cash').check()
        await page.evaluate("$('.print-submit').trigger('click');$('.print-submit').trigger('click')")
        await page.wait_for_function("document.querySelector('.print-close').textContent==='Close'")
        assert len(posts)==4 and max_in_flight==1
        assert [x['id'] for x in posts]==['1','2','3','4']
        assert [x['copies'] for x in posts]==['1','1','1','2']
        assert [x['expected_amount'] for x in posts]==['0.15','0.70','0.30','0.70']
        assert all(x['cash_received']=='1' and x['request_id'] for x in posts)
        result=await page.locator('.print-results').inner_text()
        for expected in ['Accepted by print system','NOT released','STATUS UNCERTAIN','Request failed']:
            assert expected in result,result
        await page.evaluate("$('.print-submit').trigger('click')")
        await page.wait_for_timeout(150);assert len(posts)==4
        await close()
        # Expired session stops unattempted jobs; never resubmit automatically.
        await select('1','2','3','4');await button.click();await total('$1.85')
        state['outcomes']={'1':'expired'}
        await page.locator('.print-cash').check();await page.locator('.print-submit').click()
        await page.wait_for_function("document.querySelector('.print-close').textContent==='Close'")
        assert len(posts)==5
        assert (await page.locator('.print-results').inner_text()).count('NOT attempted')==3
        await close()
        assert not errors,errors
        messages=await page.evaluate('testMessages')
        assert len(messages)==2,messages
        # Review images: actual exported UI with synthetic data and intercepted HTTP.
        if os.environ.get('PRINT_SCREENSHOTS'):
            for asset in ['bootstrap-4.0.0.min.css','dataTables.bootstrap4.min.css']:
                await page.add_style_tag(content=Path('/assets/'+asset).read_text())
            await page.add_style_tag(content=Path('/work/root/static/css/main.css').read_text())
            await page.add_style_tag(content="body {padding:24px;background:#f5f7fa;} .review-banner {padding:12px;background:#17334d;color:white;margin-bottom:20px;border-radius:4px;}")
            await page.evaluate("""document.body.insertAdjacentHTML('afterbegin','<div class="review-banner">Libki staff printing — review preview • sample documents and prices</div>')""")
            state['visible']=['1','2','3','4'];state['outcomes']={}
            await reload()
            await select('1','4')
            await page.screenshot(path='/out/01-staff-select-documents.png',full_page=True)
            await button.click();await total('$0.85')
            await page.locator('#staff-print-review .modal-content').screenshot(path='/out/02-staff-price-total.png')
            await page.locator('.print-copies').nth(1).fill('5');await total('$1.90')
            await page.locator('#staff-print-review .modal-content').screenshot(path='/out/03-staff-per-document-copies.png')
            await page.locator('.print-cash').check()
            await page.locator('#staff-print-review .modal-content').screenshot(path='/out/04-staff-cash-confirmation.png')
            await page.locator('.print-submit').click()
            await page.wait_for_function("document.querySelector('.print-close').textContent==='Close'")
            await page.locator('#staff-print-review .modal-content').screenshot(path='/out/05-staff-release-results.png')
            await close()
            state['visible']=['90'];await reload()
            await page.locator('tr[id="90"]').hover()
            await page.locator('#print-table-row-toolbar-release').click();await total('$0.15')
            await page.locator('#staff-print-review .modal-content').screenshot(path='/out/06-staff-reprint-review.png')
            await close()
            state['visible']=['1','2','3','4'];state['outcomes']={'2':'fail','3':'uncertain','4':'network'}
            await reload();await select('1','2','3','4');await button.click();await total('$1.85')
            await page.locator('.print-cash').check();await page.locator('.print-submit').click()
            await page.wait_for_function("document.querySelector('.print-close').textContent==='Close'")
            await page.locator('#staff-print-review .modal-content').screenshot(path='/out/07-staff-partial-results.png')
            await close()
        await browser.close()
    print(json.dumps({'result':'PASS','synthetic_posts':len(posts),'production_posts':0,
        'checks':['dedicated Select/no CUPS','one Print selected control','stored quantities','per-file copies/prices',
        'Main/Genealogy four routes','cash reset/invalid quantities','same-page refresh/hidden selection pruning',
        'history reprint','20-job limit','failed/delayed pricing','sequential partial outcomes',
        'double-click/completed-submit guard','session-expiry stops remaining jobs']}))

asyncio.run(main())
