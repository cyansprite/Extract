# -*- coding: utf-8 -*-
import re
import json
import urllib
import urllib.request
import urllib.parse

from cm import register_source, Base
register_source (
        name='Register',
        abbreviation='"',
        word_pattern=r'\w+',
        scoping=False,
        priority=9,
)

class Source(Base):
    def __init__(self, vim):
        super(Source, self).__init__(vim)
        self.vim = vim
        self.doit = self.vim.eval("g:extract_loadNCM")

    def cm_refresh(self, info, ctx):
        if self.doit:
            ls = self.vim.eval('extract#getregistercompletions()')
            self.complete(info, ctx, ctx['startcol'], ls)
        else:
            return []
