# Vim/Neovim plugin for Kite


### Features

- [Integrates with Kite Sidebar (macOS)](#kite-sidebar)
- [Completions](#completions)
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

You can configure how the completions behave with `&completeopt`.  We recommend:

```viml
set completeopt+=noinsert  " don't insert any text until user chooses a match
set completeopt-=noselect  " do    select first match
```

If you want to see documentation in the preview window for each completion option, use:

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

