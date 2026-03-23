# Emacstreak

GitHub streak stats on Emacs.
This is a feature-less port of [DenverCoder1/github-readme-streak-stats](https://github.com/DenverCoder1/github-readme-streak-stats) in Emacs Lisp.

![](./emacstreak.png)

## Features

- SVG card of the following stats.
  - Total contributions
  - Current streak
  - Longest streak
- Themes as in `github-readme-streak-stats`.
- Written in Emacs Lisp.

### Unimplemented features

- No customizable [options in github-readme-streak-stats](https://github.com/DenverCoder1/github-readme-streak-stats?tab=readme-ov-file#-options) except for `user` and `theme`.

## Setup

### Installation

Clone the repository from GitHub.

```console
$ git clone https://github.com/iquiw/emacstreak.git
```

Add the directory to `load-path` and require `emacstreak`.

```emacs-lisp
(add-to-list 'load-path "/path/to/emacstreak")
(require 'emacstreak)
```

### Configuration

Specify GitHub token in the environment variable `GITHUB_TOKEN` or Emacs
variable `emacstreak-github-token`.

```emacs-lisp
(setopt emacstreak-github-token "github_pat_...")
```

To configure theme, specify theme name symbol to `emacstreak-theme`
variable.
Refer to [github-readme-streak-stats/docs/themes.md](https://github.com/DenverCoder1/github-readme-streak-stats/blob/main/docs/themes.md) for available themes.

```emacs-lisp
(setopt emacstreak-theme 'nord)
```

## Usage

### Interactive display

<kbd>M-x</kbd> `emacstreak-show-svg` shows SVG card of the specified user
without animation in the popup buffer.

With the prefix-argument, it uses the last queried stats instead of
querying GitHub GraphQL API.

### Interactive save

<kbd>M-x</kbd> `emacstreak-save-svg` saves SVG card of the specified user in
the specified file.

With the prefix-argument, it uses the last queried stats instead of
querying GitHub GraphQL API.

### Batch save

Provided that environment variable `GITHUB_TOKEN` is defined, the following
command outputs SVG card of `<user>` into `<output svg>`.

```console
$ emacs --batch -L . -l emacstreak.el --eval '(emacstreak-save-svg "<user>" "<output svg>")'
```
