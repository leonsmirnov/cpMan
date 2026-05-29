# Resolution Center reply — paste when resubmitting

---

```
Hello App Review,

Thank you for the feedback on cpMan (com.cpman.app). We addressed both points
in build 4:

1) Guideline 2.1(a) — Demo content
   Customers launch with an empty clipboard history. For review, load 15
   fictional sample clips via Terminal (cpMan must be quit first):

   killall cpMan 2>/dev/null; open -n -a "/Applications/cpMan.app" --args -CPManDemoMode

   Alternate:
   killall cpMan 2>/dev/null; CPMAN_DEMO_MODE=1 /Applications/cpMan.app/Contents/MacOS/cpMan &

   Then press ⌃⌥V to open the picker with populated sample data.
   There is no demo option in the customer-facing menu.

2) Guideline 1.5 — Support URL
   Support URL: https://leonsmirnov.github.io/cpMan/support/
   (hosted HTML page with contact email and FAQ, not a raw GitHub markdown file)

Please let us know if you need anything else.

Best regards,
Leon Smirnov
```
