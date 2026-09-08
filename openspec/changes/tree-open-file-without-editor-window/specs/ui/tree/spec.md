## MODIFIED Requirements

### Requirement: Tree window is not an edit target

The tree buffer SHALL be a scratch non-file buffer. The tree window SHALL keep that buffer; an edit or picker MUST NOT replace it in place. Opening a file while the tree is focused SHALL land in a normal editor window. A normal editor window is a non-floating window that is not the tree and is not a terminal. If no such window exists, the system SHALL create one and open the file there. Opening SHALL NOT raise an error because the tree window forbids replacing its buffer.

#### Scenario: File from a picker

- **WHEN** the tree window is focused
- **AND** the user opens a file from a picker
- **THEN** the file opens in an editor window
- **AND** the tree buffer remains in the tree window

#### Scenario: Enter on a file

- **WHEN** the cursor is on a file in the tree
- **AND** the user presses Enter
- **THEN** that file is opened in an editor window
- **AND** the tree window still shows the tree

#### Scenario: Enter when no editor window remains

- **WHEN** the tree is the only non-floating window
- **AND** the cursor is on a file in the tree
- **AND** the user presses Enter
- **THEN** that file is opened in a new editor window
- **AND** the tree window still shows the tree
- **AND** no error is shown about switching buffers

#### Scenario: Enter after deleting the displayed file

- **WHEN** a file is shown in the editor window beside the tree
- **AND** the user deletes that file from the tree
- **AND** they press Enter on another file
- **THEN** that other file is opened in an editor window
- **AND** the tree window still shows the tree
- **AND** no error is shown about switching buffers

#### Scenario: Enter does not use a float or terminal

- **WHEN** the tree is open
- **AND** the only other window is a floating terminal
- **AND** the user presses Enter on a file
- **THEN** the file opens in a new editor window
- **AND** the floating terminal is unchanged
- **AND** the tree window still shows the tree

### Requirement: Tree updates after a successful create

After a successful file create, the tree SHALL refresh and reveal the new file, and the file SHALL open in an editor. After a successful directory-only create, the tree SHALL refresh and reveal that directory. Opening the new file SHALL use the same editor-window rules as Enter on a file, including creating an editor window when none remains.

#### Scenario: File create follows into the editor

- **WHEN** a new file is created successfully
- **THEN** the tree shows the new file
- **AND** the file is opened for editing

#### Scenario: File create when no editor window remains

- **WHEN** the tree is the only non-floating window
- **AND** the user creates a new file successfully
- **THEN** the tree shows the new file
- **AND** the file is opened in a new editor window
- **AND** the tree window still shows the tree
