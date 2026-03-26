;; Tests for emacstreak.el.   -*- lexical-binding: t; -*-
(require 'ert)

(require 'emacstreak)

(ert-deftest test-emacstreak--last-day ()
  (should (equal (emacstreak--last-day 2010) "2010-12-31T23:59:59Z"))
  (let ((ct (current-time)))
    (should (equal (emacstreak--last-day (decoded-time-year (decode-time ct t)))
                   (format-time-string "%Y-%m-%dT23:59:59Z" (time-add ct (* 24 60 60)))))))

(ert-deftest test-emacstreak--format-number ()
  (should (equal (emacstreak--format-number 1) "1"))
  (should (equal (emacstreak--format-number 12) "12"))
  (should (equal (emacstreak--format-number 123) "123"))
  (should (equal (emacstreak--format-number 1234) "1,234"))
  (should (equal (emacstreak--format-number 12345) "12,345"))
  (should (equal (emacstreak--format-number 123456) "123,456"))
  (should (equal (emacstreak--format-number 1234567) "1,234,567")))

(ert-deftest test-emacstreak--format-date ()
  (should (equal (emacstreak--format-date (parse-time-string "2025-03-26T00:00:00Z") 2026) "Mar 26, 2025"))
  (should (equal (emacstreak--format-date (parse-time-string "2026-03-06T00:00:00Z") 2026) "Mar 06")))

(ert-deftest test-emacstreak--format-range ()
  (should (equal (emacstreak--format-range "2026-03-10" "2025-03-01" "2025-03-10") "Mar 01, 2025 - Mar 10, 2025"))
  (should (equal (emacstreak--format-range "2026-03-10" "2026-03-01" "2026-03-10") "Mar 01 - Present"))
  (should (equal (emacstreak--format-range "2026-03-10" "2026-03-01" "2026-03-10" t) "Mar 01 - Mar 10"))
  (should (equal (emacstreak--format-range "2026-03-10" "2026-03-10" "2026-03-10") "Mar 10"))
  (should (equal (emacstreak--format-range "2026-03-10" "2025-12-31" "2026-03-05") "Dec 31, 2025 - Mar 05")))
