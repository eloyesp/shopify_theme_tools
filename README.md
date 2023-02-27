# Shopify tools

Building shopify themes requires a lot of repetitive paperwork, the idea is to
get rid of some of that work automating some tasks.

## Theme schemas

Theme have lots of details written on a really hard to read JSON, it is not
just that it is hard to read, but the structure of those makes it really boring
to write and edit those. So the idea is to create a YAML (a slightly better
JSON) schema of the full theme, so you can write in a concise file everything
and some ruby tools will keep everything moving.

The theme schema reads like this:

``` yaml

---
theme:
  name: Skeleton
  version: '0.1.0'
  author: Eloy
  documentation: https://github.com/eloyesp/skeleton
  support: https://github.com/eloyesp/skeleton/issues
categories:
  name:
    setting:
      type: image_picker
sections:
  name:
    tag: section
    setting_name:
      type: image_picker
```

With that in place, the `schema_load` tool, should get rid of writing the verbose JSON
version.
