## ADDED Requirements

### Requirement: Files show an A M or D postfix

A shown file that is not gitignored SHALL append a single letter after the name when git reports it as added, modified, or deleted. Mapping: untracked and added → `A`; modified, renamed, or copied → `M`; deleted → `D`. If `+N-M` is also present, the letter SHALL come after that count. Gitignored files SHALL NOT show the letter.

#### Scenario: Modified file

- **WHEN** a visible file is modified in git
- **AND** it is not gitignored
- **THEN** the row includes `M` after the name

#### Scenario: Untracked file is A

- **WHEN** a visible file is untracked
- **THEN** the row includes `A` after the name

#### Scenario: Letter follows plus-minus counts

- **WHEN** a file has numstat `+23-23` and is modified
- **THEN** the row contains ` +23-23` and then `M`

#### Scenario: Gitignored file has no AMD letter

- **WHEN** a file is marked gitignored
- **AND** git would otherwise classify it as modified
- **THEN** the row does not include `A`, `M`, or `D` as a git postfix

### Requirement: Directories show an aggregated DMA summary after the name

A shown directory or root that is not gitignored SHALL append the unique letters from its subtree in canonical order **D** then **M** then **A** (for example `DMA`, `MA`, `D`). Each letter SHALL use the deleted, modified, or added highlight. The summary SHALL include letters from scanned children and from git-deleted paths under that directory even if those files are not listed as tree nodes. Gitignored directories SHALL NOT show a summary.

#### Scenario: Mixed subtree

- **WHEN** a directory has a deleted child, a modified child, and an added child
- **AND** the directory is not gitignored
- **THEN** the row includes `DMA` after the name
- **AND** `D` uses the deleted highlight, `M` the modified highlight, and `A` the added highlight

#### Scenario: Nested roll-up

- **WHEN** directory `src` contains `src/app` whose only dirty file is modified
- **THEN** both `src/app` and `src` include `M` after the name

#### Scenario: Clean directory

- **WHEN** a directory’s subtree has no added, modified, or deleted files
- **THEN** no DMA summary is appended

### Requirement: AMD attaches without a filesystem re-scan

A/M/D data SHALL be applied after the filesystem listing is already shown. When it arrives, the system SHALL stamp existing nodes and re-render. It MUST NOT re-list directories to apply AMD. It MUST NOT run `git status` with `--ignored=matching`. A missing git root or a failed git command SHALL leave nodes without AMD and MUST NOT fail the scan.

#### Scenario: Tree is usable before AMD returns

- **WHEN** a repository tree is opened
- **THEN** the filesystem listing is shown without waiting for AMD letters
- **AND** file postfixes and directory DMA appear after status arrives without a new directory listing

#### Scenario: Not a git repository

- **WHEN** the tree root is not inside a git repository
- **THEN** the scan still succeeds
- **AND** no A/M/D postfix or directory DMA is shown
