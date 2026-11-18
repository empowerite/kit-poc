---
# kit:generated -- the prose style, from the style/prose package
# see: kit packages remove style/prose, or "Changing what kit adds" in .kit/1st.md
kind:
  - text
---
# Prose style

Applies to every file of kind `text`: the prose of a document and the comments in code and configuration alike.
The style for the file's kind, where the repository takes one, also applies.

1. Write plain declarative sentences, and make who or what acts the subject: "kit refuses the name", not
   "the name is refused". Say "you" to the reader: "the name you typed", not "the name the caller typed".
2. Describe in the indicative and instruct in the imperative. What a function, command, or file does is
   indicative: "`kit check` compares every delivered file with the pinned release." A step the reader takes is
   imperative: "Run `kit check` before you push." What the reader does on a screen is imperative too: "Click a
   row to open its card", not "a click on a row opens its card". A comment that documents a function does
   both: `# use:find <module> prints every <module>.sh on the path. Call use:load-path first.`
3. Give each sentence one idea. Split a sentence at its second colon or semicolon, or when it
   passes about 30 words. Put cases, fields, and steps in a list, one per item. Write "The
   cache holds ten entries. A new entry replaces the oldest. The menu shows every entry.", not
   "The cache holds ten entries; a new entry replaces the oldest: the menu shows them all."
4. Use the common word. Write "such as" before an example and "because" before a cause, and keep "as"
   for a comparison: "`last` is null, because the server does not report it", not "`last` is null, as
   the server does not report it". Prefer "only", "per", "except", "is", "shows", and "is not a" to a
   rarer word that means the same: "commits only these paths", not "commits these paths alone".
5. Repeat the noun. Do not leave a possessive or a pronoun to carry the noun across a clause: "the
   second file's rows follow the first file's rows", not "the second file's follow the first's".
6. Define a term of the project's own where the term first appears on a page, or link to its definition.
   Use one word for one thing: a page that calls a thing a "stage" does not also call it a "tab".
7. Expand an uncommon acronym the first time it appears.
8. Use the serial comma in every list of three or more.
9. Do not end a paragraph on a slogan.
10. Do not repeat another file's text, whether that file holds prose, code, or
    configuration. Point to the file with `see: <ref>`: a page that needs the
    pinned versions points to the file that pins them, and does not copy the list.
