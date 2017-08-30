# Vim/Neovim plugin for Kite


### Features

- [Integrates with Kite Sidebar (macOS)](#kite-sidebar)
- [Completions](#completions)
- [Documentation](#documentation)
- ...


### Installation

Download Kite from https://kite.com.  During Kite's installation process, select Vim and/or Neovim in the list of editors and Kite will install this plugin for you.

Kite will also keep the plugin up to date automatically.


### Manual installation

#### Vim

Assuming your Vim configuration is in `~/.vim/`:

```sh
$ mkdir -p ~/.vim/pack/kite/start/kite
$ git clone https://github.com/kiteco/vim-plugin.git ~/.vim/pack/kite/start/kite/
```

Restart Vim.


#### Neovim

Assuming your Neovim configuration is in `~/.config/nvim`:

```sh
$ mkdir -p ~/.config/nvim/pack/kite/start/kite
$ git clone https://github.com/kiteco/vim-plugin.git ~/.config/nvim/pack/kite/start/kite/
```

Restart Neovim.


### Kite Sidebar

As you edit your code in Vim/Neovim, the Kite Sidebar will show completions, popular patterns, code examples, and documentation for the code under the cursor.


### Completions

Kite's ranked completions are integrated with Vim's insert-mode completion, specifically the user-defined completion.

By default Kite's completions will show up automatically as you type.  You can opt out via:

```viml
let g:kite_auto_complete=0
```

You can manually invoke the completions in insert mode with `<C-X><C-U>`.  See `:h i_CTRL-X_CTRL-U` for details.

Normally you insert the currently selected completion option with `<C-y>`.  If you'd like to use `<Tab>` instead / as well, add this to your vimrc:

```viml
let g:kite_tab_complete = 1
```

You can configure how the completions behave with `&completeopt`.  The plugin configures `&completeopt` as follows if and only if you haven't configured it yourself:

```viml
set completeopt-=menu
set completeopt+=menuone   " show the popup menu even when there is only 1 match
set completeopt-=longest   " don't insert the longest common text
set completeopt-=preview   " don't show preview window
set completeopt+=noinsert  " don't insert any text until user chooses a match
set completeopt-=noselect  " select first match
```

To see documentation in the preview window for each completion option, copy all the lines above into your vimrc and change the preview line to:

```viml
set completeopt+=preview
```

To have the preview window automatically closed once a completion has been inserted:

```viml
autocmd CompleteDone * if !pumvisible() | pclose | endif
```

We also recommend:

```viml
set shortmess+=c    " turn off completion messages
set belloff+=ctrlg  " if vim beeps during completion
```


### Documentation

Press `K` when the cursor is on a keyword to see documentation in the status line.  If you have mapped `K` already, the plugin won't overwrite your mapping.

You can set an alternative mapping, e.g. to `gK`, like this:

```viml
nmap <silent> gK <Plug>(kite-hover)
```

In addition to documentation Kite can also show code snippets, links to relevant StackOverflow answers, all the places you've use the keyword in your code, and links to fuller online documentation.  To see all this, set:

```viml
let g:kite_documentation='window'
```

This will make the plugin open a split window with all the relevant information.  Press `<CR>` on any item to see more information.

The default behaviour for usages and definitions is to show them in the code window you came from.  To see them in the preview window instead:

```viml
let g:kite_preview_code=1
```

By default you need to type `K` (or whatever you have mapped to `<Plug>(kite-hover)`) each time you want to see documentation for the keyword under the cursor.  To have the documentation continually update itself as you move from keyword to keyword:

```viml
let g:kite_documentation_continual=1
```

