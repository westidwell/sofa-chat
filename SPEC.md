# Answer format, version 1

The model is asked to answer in this JSON shape, enforced with a JSON schema (`AnswerSchema.format`), so every reply can be shown the same way on a screen and read aloud.

```json
{
  "say": "Here's a made-up chart of snack votes from movie night. Popcorn won by a mile.",
  "title": "Movie night snack votes",
  "chart_title": "Votes (made-up data)",
  "bars": [
    { "label": "Popcorn", "value": 12 },
    { "label": "Nachos", "value": 9 }
  ]
}
```

| Field | Type | Meaning |
| --- | --- | --- |
| `say` | string, required | The answer in plain spoken sentences: no markdown, lists, emoji or links. Shown in large type and read aloud. |
| `title` | string | A heading of two to six words, or empty. |
| `chart_title` | string | Heading for the chart, or empty when there is no chart. |
| `bars` | array of `{label, value}` | Bars for a simple bar chart, or empty. The model is asked for up to 8; readers keep at most 12. |

Rules for readers:

- Treat a missing `title`, `chart_title` or `bars` as empty.
- Show a chart only when `bars` has at least one item.
- Values are plain numbers. Labels are short text.
- If the reply is plain text instead of JSON, show the text as `say` and leave the rest empty.
- If the reply starts as JSON but can't be read, for example because it was cut off, treat it as an error rather than showing raw braces.

The schema is strict (`additionalProperties: false`), so new fields will come as a new version of this format.
