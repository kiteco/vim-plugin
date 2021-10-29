## Kite-LSP

Kite comes with a language server adapter that may be used to enable Kite
completions via your favorite LSP client.
Other Kite features than completions are not well-supported via LSP, so you
should still install the Kite plugin for Vim.

#### The Kite-LSP adapter may be run as follows, depending on your operating system:
```bash
/Applications/Kite.app/Contents/MacOS/kite-lsp
~/.local/share/kite/current/kite-lsp
C:\Program Files\Kite\kite-lsp.exe
```

If you installed Kite to a non-standard location, you may need to appropriately
modify the executable path.

### Vim-LSP

As today the [LSP integration in vim](https://github.com/prabirshrestha/vim-lsp) is just available in the nightlies.  
To enable the support in this case:

```
au User lsp_setup call lsp#register_server({
     \ 'name': 'kite',
     \ 'cmd': '~/.local/share/kite/current/kite-lsp --editor=vim',
     \ 'whitelist': ["php", "javascript", "python", "bash"],
     \ })
```

### Coc.nvim

We have tested Kite-LSP with the full-featured
[coc.nvim](https://github.com/neoclide/coc.nvim) completions plugin.
However, it should likely work with most LSP client plugins.

In order to enable Kite-LSP, add the following to your coc.nvim configuration
(`:CocConfig`):
```json
{
  "languageserver": {
    "kite": {
      "command": "/Applications/Kite.app/Contents/MacOS/kite-lsp",
      "filetypes": ["python", "go", "javascript"]
    }
  }
}
```
Be sure to use the [right command for your OS](https://github.com/kiteco/vim-plugin/blob/master/LSP.md#the-kite-lsp-adapter-may-be-run-as-follows-depending-on-your-operating-system).

Add to `"filetypes"` any languages for which you would like to enable Kite
completions.

You should also disable the Kite plugin's completions to avoid getting
duplicate completions:
```viml
let g:kite_completions=0
```
