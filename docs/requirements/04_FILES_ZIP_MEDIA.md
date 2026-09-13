# FILES, ZIP, IMAGE AND VIDEO REQUIREMENTS

## File composer

Allow:
- multiple attachments
- ZIP
- documents
- code
- images
- videos
- audio

## ZIP analysis

Must:
- inspect archive safely
- build tree
- detect project type
- index relevant source files
- search exact filenames
- search semantic chunks
- track changed files
- export updated ZIP

Must protect against:
- path traversal
- ZIP slip
- archive bombs
- symlink tricks where relevant
- oversized expansion

## Images

Support:
- visual Q&A
- UI screenshot analysis
- error screenshot diagnosis
- design reconstruction
- OCR where useful

## Video

Do:
- metadata
- representative frames
- transcript
- frame + transcript linking
- timeline analysis

## Generated files

All generated files must be real downloadable files.

No fake download UI.
