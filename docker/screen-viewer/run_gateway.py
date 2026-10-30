# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright 2026 City of Clinton, Iowa
"""Start the Libki gateway without logging bearer-token URLs."""
import logging
from websockify.websocketproxy import websockify_init

if __name__ == "__main__":
    # websockify can include raw tokens in errors. Do not enable request/debug
    # logging here. Monitor process health and Libki's structured audit instead.
    logging.disable(logging.CRITICAL)
    websockify_init()
