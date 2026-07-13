set clipboard=unnamedplus
set tabstop=4
set shiftwidth=4
set expandtab

syntax on

" 设置tab宽度为4个空格
set tabstop=4
set shiftwidth=4
set expandtab

" 自动缩进
set autoindent

" 显示行号和列号
set number
set ruler

" 显示当前行
set cursorline

" 设置行号颜色为灰色
highlight LineNr ctermfg=gray

" 让vim可以用鼠标滚轮
set mouse=a

call plug#begin('~/.vim/plugged')
" Shorthand notation for plugin
Plug 'jiangmiao/auto-pairs'
Plug 'vim-airline/vim-airline'
Plug 'preservim/nerdtree'
call plug#end()

set laststatus=2  "永远显示状态栏
let g:airline_powerline_fonts = 1  " 支持 powerline 字体
let g:airline#extensions#tabline#enabled = 1 " 显示窗口tab和buffer
