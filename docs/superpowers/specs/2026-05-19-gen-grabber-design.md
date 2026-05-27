# Gen Grabber — Design Spec

A native macOS SwiftUI app for organizing genealogy record screenshots with structured filenames.

## Problem

When researching genealogy records on LaFrance/GenealogyQuebec, the workflow of screenshotting records, manually pasting into Preview, and renaming files is tedious and error-prone. Gen Grabber streamlines this into a single app where you enter metadata, paste images into labeled slots, and save everything with correct filenames in one action.

## Architecture

**Platform:** Native macOS app using SwiftUI, targeting macOS 14+ (Sonoma).

**Single-window app** with:
1. A session-level people list
2. A tab bar with record-type creation buttons
3. A two-column layout per tab (form left, images right)
4. A bottom bar with Save All

No persistence/database needed — this is a session-based tool. Data lives in memory until saved to disk.

## People List (Session Header)

A list of people at the top of the window. Each person has:

| Field | Description |
|-------|-------------|
| Gender | M or F (shown as a colored badge) |
| Last Name | e.g. "Girard" |
| First Name | e.g. "Joseph" |

The user can:
- Add people via "+ Add Person" (new row with gender toggle, last name, first name fields)
- Remove people via an "x" button on each row
- Add as many people as needed (handles remarriages, multiple family members)

These names are referenced by tabs to construct filenames. A person cannot be removed if they are referenced by an existing tab.

**Example session with a remarriage:**
- M: Girard, Joseph
- F: Vanasse, Marie Anne
- F: Tremblay, Catherine

## Record Types

Three types, chosen when creating a new tab:

### Birth (b)
- References one person from the people list
- Filename pattern: `YEAR-(b)-lastname-firstname-RECORDID{suffix}.png`

### Wedding (w)
- References two people from the people list (groom + bride)
- Filename pattern: `YEAR-(w)-groom-lastname-groom-firstname-bride-lastname-bride-firstname-RECORDID{suffix}.png`

### Sepulture (s)
- References one person from the people list
- Filename pattern: `YEAR-(s)-lastname-firstname-RECORDID{suffix}.png`

All names in filenames are lowercased. Spaces in first names become hyphens (e.g. "Marie Anne" -> "marie-anne").

## Tab Structure

### Tab Bar

- Each record is a tab, labeled automatically:
  - Wedding: "W: Joseph + Marie Anne"
  - Birth: "B: Joseph"
  - Sepulture: "S: Marie Anne"
- A special "Notes" tab (always present, cannot be closed)
- Three creation buttons on the right side of the tab bar: **+ Birth**, **+ Wedding**, **+ Sepulture**
- Tabs can be closed (with confirmation if they have pasted images)

### Creating a New Tab

**+ Wedding:** Opens a popover showing the people list. User picks the groom, then the bride. Tab is created.

**+ Birth / + Sepulture:** Opens a popover showing the people list. User picks one person. Tab is created.

The tab is locked to its type and selected people after creation.

### Per-Tab Layout (Two-Column)

**Left Column — Metadata:**
- Selected people (read-only, showing who the tab references)
- Year text field
- Page groups (see below)
- Live filename preview at the bottom

**Right Column — Image Slots:**
- LaFrance slot (always exactly 1, shown at the top)
- Page groups, each containing:
  - Record image slot
  - Closeup image slot(s)

### Page Groups

A record may span multiple scanned pages. Each page has:
- A Record ID text field (e.g. "d1p_1142c0453")
- A record image slot (the full scanned page)
- A closeup image slot

The first page group is always present. The user can:
- Click "+ Add Page" to add another page group (with its own Record ID, record slot, closeup slot)
- Remove additional page groups (with an "x" button)

### Image Slots

Each slot is a drop zone that accepts pasted images:
- Click a slot to focus it, then Cmd+V to paste from clipboard
- Slot shows a thumbnail when an image is pasted
- Click thumbnail to preview full size in a popover or sheet
- Right-click or click an "x" overlay to clear a slot
- Visual states: empty (dashed border), focused (highlighted border), filled (green border with thumbnail)

## Filename Construction

All filenames are constructed from the metadata fields. Format:

```
{base}-{recordid}{suffix}.png
```

Where `{base}` depends on the record type:
- Birth: `YEAR-(b)-lastname-firstname`
- Wedding: `YEAR-(w)-groom-lastname-groom-firstname-bride-lastname-bride-firstname`
- Sepulture: `YEAR-(s)-lastname-firstname`

And `{suffix}` depends on the image type:
- LaFrance: `-lafrance` (uses the first page's record ID)
- Record page: (no suffix)
- Closeup: `-closeup` (single closeup) or `-closeup-1`, `-closeup-2` (multiple closeups on the same page)

When a record has multiple pages with different record IDs, each page's images use that page's record ID.

### Filename Examples

**Single-page wedding:**
```
1732-(w)-girard-joseph-vanasse-marie-anne-d1p_1142c0453-lafrance.png
1732-(w)-girard-joseph-vanasse-marie-anne-d1p_1142c0453.png
1732-(w)-girard-joseph-vanasse-marie-anne-d1p_1142c0453-closeup.png
```

**Multi-page wedding (same record ID, 2 closeups):**
```
1732-(w)-girard-joseph-vanasse-marie-anne-d1p_1142c0453-lafrance.png
1732-(w)-girard-joseph-vanasse-marie-anne-d1p_1142c0453.png
1732-(w)-girard-joseph-vanasse-marie-anne-d1p_1142c0453-closeup-1.png
1732-(w)-girard-joseph-vanasse-marie-anne-d1p_1142c0453-closeup-2.png
```

**Multi-page wedding (different record IDs):**
```
1787-(w)-languirand-pierre-levasseur-marie-anne-d1p_03871069-lafrance.png
1787-(w)-languirand-pierre-levasseur-marie-anne-d1p_03871069.png
1787-(w)-languirand-pierre-levasseur-marie-anne-d1p_03871069-closeup.png
1787-(w)-languirand-pierre-levasseur-marie-anne-d1p_03871070.png
1787-(w)-languirand-pierre-levasseur-marie-anne-d1p_03871070-closeup.png
```

**Birth:**
```
1845-(b)-girard-joseph-12345-lafrance.png
1845-(b)-girard-joseph-12345.png
1845-(b)-girard-joseph-12345-closeup.png
```

## Notes Tab

- A dedicated tab with a free-form text area
- Always present (cannot be closed)
- Saved as `notes.txt` in the output folder
- Skipped if empty (no file written)

## Save All

- A "Save All..." button in the bottom bar
- Opens a macOS native folder picker (NSOpenPanel in directory mode)
- Writes all images from all tabs as PNG files with constructed filenames
- Writes `notes.txt` if the notes tab has content
- Shows a confirmation after save with the file count
- Bottom bar shows a summary: "3 records, 8 images"

## Clear All

- A "Clear All" button in the bottom bar
- Clears all tabs, images, and form fields
- Resets to a fresh session (empty people list, no record tabs, empty notes)
- Requires confirmation dialog

## Live Filename Preview

At the bottom of each tab's left column, a preview area shows the filenames that will be generated for that tab. Updates live as the user types in the year or record ID. Record IDs that haven't been entered yet show as `{recordid}`.

## Image Format

- All images saved as PNG
- Images are captured from the macOS clipboard (NSPasteboard)
- No format conversion needed — screenshots are already PNG

## Window Sizing

- Default window size: ~900x600
- Minimum size: ~700x500
- The left column has a fixed width (~200px), the right column fills remaining space
- Images scale to fit their slots while maintaining aspect ratio
