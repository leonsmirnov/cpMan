# Resolution Center reply — paste when resubmitting

---

```
Hello App Review,

Thank you for the feedback on cpMan (com.cpman.app). We addressed both points
in build 2:

1) Guideline 2.1(a) — Demo content
   Demo content is no longer loaded for customers on first launch. Reviewers
   can load 15 fictional sample clips on demand:

   Terminal (recommended):
   killall cpMan 2>/dev/null; open -b com.cpman.app --args -CPManDemoMode

   Or: menu bar icon → "Load Demo Content"

   Then press ⌃⌥V to open the picker with populated sample data.

2) Guideline 1.5 — Support URL
   Support URL: https://leonsmirnov.github.io/cpMan/support/
   (hosted HTML page with contact email and FAQ, not a raw GitHub markdown file)

Please let us know if you need anything else.

Best regards,
Leon Smirnov
```
