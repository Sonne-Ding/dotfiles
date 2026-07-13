# Linux/macOS dotfiles

用于在 Ubuntu/Debian 与 macOS 设备间迁移 zsh 和 Vim 配置。

仓库只保存自有配置：

- `.zshrc`
- `.vimrc`
- 安装脚本

`.zshrc.local`、`.ssh`、oh-my-zsh、vim-plug 及其他插件不会同步。配置部署采用普通文件复制，不创建符号链接。

## 使用

克隆仓库后执行：

```bash
./install.sh
```

脚本会分别询问是否配置 zsh 和 vim。输入 `yes` 或 `y` 执行，输入 `no` 或 `n` 跳过。

也可以单独执行：

```bash
./zsh-install.sh
./vim-install.sh
```

脚本会根据自身位置查找配置，因此可以从任意工作目录运行。

## 系统依赖

- Ubuntu/Debian：缺少命令时通过 apt 安装。
- macOS：优先复用系统已有命令，缺少命令时通过 Homebrew 安装。

脚本不会自动安装 Homebrew。如果 macOS 缺少依赖且未安装 `brew`，脚本会停止并提示先按照 [Homebrew 官方说明](https://brew.sh/) 手动安装。

Apple Silicon 默认将 Homebrew 安装到 `/opt/homebrew`，Intel Mac 通常安装到 `/usr/local`。运行本仓库脚本前，应按照 Homebrew 安装提示将对应的 `brew shellenv` 加入当前 shell 环境，确保 `brew` 可通过 `PATH` 找到。

## zsh 安装内容

`zsh-install.sh` 将：

1. 在缺失时通过 apt 或 Homebrew 安装 zsh、git 和 `.zshrc` 中 `cp-clean` 所需的 rsync。
2. 在缺失时浅克隆 oh-my-zsh。
3. 在缺失时浅克隆 zsh-autocomplete。
4. 备份目标设备已有的 `~/.zshrc`，再复制仓库中的 `.zshrc`。
5. 将 zsh 设置为默认 shell；macOS 使用 Homebrew zsh 且其路径不在 `/etc/shells` 时，会先通过 sudo 添加该路径。

设备专属环境变量应写入 `~/.zshrc.local`。该文件会由 `.zshrc` 加载，但不会被本仓库同步或修改。

## Vim 安装内容

`vim-install.sh` 将：

1. 在缺失时通过 apt 或 Homebrew 安装 vim 和 curl。
2. 备份目标设备已有的 `~/.vimrc`，再复制仓库中的 `.vimrc`。
3. 在缺失时下载 vim-plug 到 `~/.vim/autoload/plug.vim`。
4. 执行 `vim +PlugInstall +qall` 安装 `.vimrc` 声明的插件。

## 备份与重复执行

当目标配置与仓库版本不同时，原文件或符号链接会被移动到：

```text
~/.dotfiles-backups/YYYYMMDD-HHMMSS/
```

目标配置已是相同的普通文件时不会重复备份或复制。第三方工具和插件已存在时也会跳过安装。

如需恢复配置，将对应备份文件复制回 `$HOME` 即可。

## 更新仓库配置

当前设备中的配置不会自动回写仓库。需要更新时，手动复制：

```bash
cp ~/.zshrc /path/to/dotfiles/.zshrc
cp ~/.vimrc /path/to/dotfiles/.vimrc
```

复制前确认没有将设备专属变量或敏感信息写入这些文件。不要将 `.zshrc.local` 或 `.ssh` 复制进仓库。
