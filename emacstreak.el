;;; emacstreak.el --- GitHub streak stats in Emacs         -*- lexical-binding: t; -*-

;; Copyright (C) 2026  Iku Iwasa

;; Author: Iku Iwasa <iku.iwasa@gmail.com>
;; Keywords: convenience

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Emacstreak provides SVG generation for GitHub streak stats.  It queries
;; GitHub GraphQL to get contribution data and generates SVG card for the
;; stats.

;;; Code:

(require 'url)
(require 'svg)

(require 'emacstreak-theme)

(defcustom emacstreak-github-token (getenv "GITHUB_TOKEN")
  "GitHub token.
Value of GITHUB_TOKEN environment variable is used by default.")

(defconst emacstreak--border-radius 4.5)
(defconst emacstreak--card-width 495)
(defconst emacstreak--card-height 195)

(defconst emacstreak--css "@keyframes currstreak {
   0% { font-size: 3px; opacity: 0.2; }
  80% { font-size: 34px; opacity: 1; }
 100% { font-size: 28px; opacity: 1; }
}
@keyframes fadein {
   0% { opacity: 0; }
 100% { opacity: 1; }
}")

(defconst emacstreak-font "Segoe UI, Ubuntu, sans-serif")

(defconst emacstreak--graphql-url "https://api.github.com/graphql")
(defconst emacstreak--contribution-years-query "query($user: String!, $from: DateTime, $to: DateTime) {
  user(login: $user) {
    createdAt
    contributionsCollection(from: $from, to: $to) {
      contributionYears
    }
  }
}")

(defconst emacstreak--contribution-days-query "query($user: String!, $from: DateTime, $to: DateTime) {
  user(login: $user) {
    createdAt
    contributionsCollection(from: $from, to: $to) {
      contributionCalendar {
        weeks {
          contributionDays {
            contributionCount
            date
          }
        }
      }
    }
  }
}")

(defvar emacstreak--last-streak-stats nil)

(defun emacstreak--last-day (year)
  "Return the last day of the YEAR."
  (let* ((ct (current-time))
         (nt (time-add ct (* 24 60 60))))
    (if (and (= year (decoded-time-year (decode-time ct t)))
             (= year (decoded-time-year (decode-time nt t))))
        (format-time-string "%Y-%m-%dT23:59:59Z" nt)
      (format "%s-12-31T23:59:59Z" year))))

(defun emacstreak--query (query user year)
  "Post QUERY to GitHub GraphQL API for USER's contribution YEAR.
Return the returned JSON as is if success.  Raise error otherwise."
  (unless emacstreak-github-token
    (user-error "GitHub token is required. Specify GitHub token in `emacstreak-github-token' variable"))
  (let* ((payload (json-serialize `((query . ,query)
                                    (variables . ((user . ,user)
                                                  (from . ,(format "%s-01-01T00:00:00Z" year))
                                                  (to . ,(emacstreak--last-day year)))))))
         (headers `(("Content-Type" . "application/json")
                    ("Authorization" . ,(concat "Bearer " emacstreak-github-token))))
         (url-request-method "POST")
         (url-request-extra-headers headers)
         (url-request-data (encode-coding-string payload 'utf-8)))

    (with-current-buffer (url-retrieve-synchronously emacstreak--graphql-url t)
      (goto-char (point-min))
      (if (and (re-search-forward "200 OK" (line-end-position) t)
               (re-search-forward "^$" nil t))
          (prog1
              (json-parse-buffer :object-type 'alist :array-type 'list)
            (kill-buffer (current-buffer)))
        (error "GitHub API call error")))))

(defun emacstreak--query-years (user)
  "Query USER's contribution years.
Return list of the contribution years in the chronological order."
  (let ((graph (emacstreak--query
                emacstreak--contribution-years-query
                user
                (decoded-time-year (decode-time)))))
    (nreverse
     (thread-last
       graph
       (alist-get 'data)
       (alist-get 'user)
       (alist-get 'contributionsCollection)
       (alist-get 'contributionYears)))))

(defun emacstreak--calculate-contributions (user today)
  "Calculate USER's contribution stats till TODAY."
  (let ((years (emacstreak--query-years user))
        (total-contributions 0)
        first-contribution
        longest-streak-start
        longest-streak-end
        (longest-streak-length 0)
        current-streak-start
        current-streak-end
        (current-streak-length 0))
    (dolist (year years)
      (let* ((graph (emacstreak--query emacstreak--contribution-days-query user year))
             (weeks (thread-last
                      graph
                      (alist-get 'data)
                      (alist-get 'user)
                      (alist-get 'contributionsCollection)
                      (alist-get 'contributionCalendar)
                      (alist-get 'weeks))))
        (dolist (week weeks)
          (dolist (day (alist-get 'contributionDays week))
            (let ((count (alist-get 'contributionCount day))
                  (date (alist-get 'date day)))
              (setq total-contributions (+ total-contributions count))

              ;; check if still in streak
              (cond
               ((> count 0)
                ;;  increment streak
                (setq current-streak-length (1+ current-streak-length))
                (setq current-streak-end date)
                ;; set start on first day of streak
                (when (= current-streak-length 1)
                  (setq current-streak-start date))
                ;; set first contribution date the first time
                (unless first-contribution
                  (setq first-contribution date))
                ;; update longestStreak
                (when (> current-streak-length longest-streak-length)
                  (setq longest-streak-start current-streak-start)
                  (setq longest-streak-end current-streak-end)
                  (setq longest-streak-length current-streak-length)))

               ;; reset streak but before today
               ((string< date today)
                (setq current-streak-length 0)
                (setq current-streak-start today)
                (setq current-streak-end today))))))))
    (list
     :total-contributions total-contributions
     :first-contribution first-contribution
     :longest-streak-start longest-streak-start
     :longest-streak-end longest-streak-end
     :longest-streak-length longest-streak-length
     :current-streak-start current-streak-start
     :current-streak-end current-streak-end
     :current-streak-length current-streak-length
     :today today)))

(defun emacstreak--style (svg)
  "Inject style element into SVG."
  (let ((style (dom-node 'style)))
    (dom-append-child style emacstreak--css)
    (dom-add-child-before svg style)))

(defun emacstreak--defs (svg)
  "Inject defs element into SVG."
  (let ((clip-path (dom-node 'clipPath '((id . "outer_rectangle"))))
        (clip-rect (dom-node 'rect
                             `((width . ,(dom-attr svg 'width))
                               (height . ,(dom-attr svg 'height))
                               (rx . ,emacstreak--border-radius))))
        (mask (dom-node 'mask '((id . "mask_out_ring_behind_fire"))))
        (mask-rect (dom-node 'rect
                             `((width . ,(dom-attr svg 'width))
                               (height . ,(dom-attr svg 'height))
                               (fill . "white"))))
        (ellipse (dom-node 'ellipse `((id . "mask-ellipse")
                                      (cx . 247.5) (cy . 32)
                                      (rx . 13) (ry . 18)
                                      (fill . "black")))))
    (dom-append-child clip-path clip-rect)
    (dom-append-child mask mask-rect)
    (dom-append-child mask ellipse)
    (svg--def svg clip-path)
    (svg--def svg mask)
    svg))

(defun emacstreak--text (svg text &rest attrs)
  "Return SVG text element with TEXT contents and pre-defined attributes.
ATTRS is appended to the element if any."
  (apply #'svg-text svg text
         :stroke-width 0 :text-anchor "middle" :stroke "none"
         :font-family emacstreak-font
         :font-style "normal"
         attrs))

(defun emacstreak--border (svg)
  "Draw border in SVG."
  (let ((g1 (svg-node svg 'g :style "isolation: isolate"))
        (rect (dom-node 'rect `((stroke . ,(emacstreak-get-color 'border)) (fill . ,(emacstreak-get-color 'background))
                                (rx . ,emacstreak--border-radius)
                                (x . 0.5) (y . 0.5)
                                (width . ,(- emacstreak--card-width 1))
                                (height . ,(- emacstreak--card-height 1)))))
        (g2 (svg-node svg 'g :style "isolation: isolate"))
        (column-width (/ emacstreak--card-width 3)))
    (dom-append-child g1 rect)
    (svg-line g2 column-width 28 column-width 170 :vector-effect "non-scaling-stroke" :stroke-width 1
              :stroke (emacstreak-get-color 'stroke) :stroke-linejoin "miter"
              :stroke-linecap "square" :stroke-miterlimit 3)
    (svg-line g2 (* column-width 2) 28 (* column-width 2) 170 :vector-effect "non-scaling-stroke" :stroke-width 1
              :stroke (emacstreak-get-color 'stroke) :stroke-linejoin "miter"
              :stroke-linecap "square" :stroke-miterlimit 3)))

(defun emacstreak--total-contributions (svg number range)
  "Draw total contribution component in SVG with NUMBER of contributions in RANGE."
  (let* ((g (svg-node svg 'g :style "isolation: isolate"))
         (column-width (/ emacstreak--card-width 3))
         (column-offset (/ column-width 2))
         (g-number (svg-node g 'g :transform (format "translate(%s, 48)" column-offset)))
         (g-label (svg-node g 'g :transform (format "translate(%s, 84)" column-offset)))
         (g-range (svg-node g 'g :transform (format "translate(%s, 114)" column-offset))))
    (emacstreak--text g-number number :x 0 :y 32 :fill (emacstreak-get-color 'sideNums)
                      :font-weight "700" :font-size "28px"
                      :style "opacity: 0; animation: fadein 0.5s linear forwards 0.6s")
    (emacstreak--text g-label "Total Contributions" :x 0 :y 32 :fill (emacstreak-get-color 'sideLabels)
                      :font-weight "400" :font-size "14px"
                      :style "opacity: 0; animation: fadein 0.5s linear forwards 0.7s")
    (emacstreak--text g-range range :x 0 :y 32 :fill (emacstreak-get-color 'dates)
                      :font-weight "400" :font-size "12px"
                      :style "opacity: 0; animation: fadein 0.5s linear forwards 0.8s")))

(defun emacstreak--current-streak (svg number range)
  "Draw current streak component in SVG with NUMBER of days in RANGE."
  (let* ((g (svg-node svg 'g :style "isolation: isolate"))
         (column-width (/ emacstreak--card-width 3))
         (column-offset (+ (/ column-width 2) column-width))
         (g-label (svg-node g 'g :transform (format "translate(%s, 108)" column-offset)))
         (g-range (svg-node g 'g :transform (format "translate(%s, 145)" column-offset)))
         (g-ring (svg-node g 'g :mask "url(#mask_out_ring_behind_fire)"))
         (g-icon (svg-node g 'g :transform (format "translate(%s, 19.5)" column-offset) :stroke-opacity 0
                            :style "opacity: 0; animation: fadein 0.5s linear forwards 0.6s"))
         (g-number (svg-node g 'g :transform (format "translate(%s, 48)" column-offset))))
    (emacstreak--text g-label "Current Streak" :x 0 :y 32 :fill (emacstreak-get-color 'currStreakLabel)
                      :font-weight "700" :font-size "14px"
                      :style "opacity: 0; animation: fadein 0.5s linear forwards 0.9s")
    (emacstreak--text g-range range :x 0 :y "21" :fill (emacstreak-get-color 'dates)
                      :font-weight "400" :font-size "12px"
                      :style "opacity: 0; animation: fadein 0.5s linear forwards 0.9s")
    (svg-circle g-ring column-offset 71 40 :fill "none" :stroke (emacstreak-get-color 'ring) :stroke-width "5"
                :style "opacity: 0; animation: fadein 0.5s linear forwards 0.4s")

    (svg-path g-icon '((moveto ((-12 . -0.5)))
                       (lineto ((15 . -0.5)))
                       (lineto ((15 . 23.5)))
                       (lineto ((-12 . 23.5)))
                       (lineto ((-12 . -0.5)))
                       (closepath))
              :fill "none")
    (svg-path g-icon '((moveto ((1.5 . 0.67)))
                       (curveto ((1.5 0.67 2.24 3.32 2.24 5.47)))
                       (curveto ((2.24 7.53 0.89 9.2 -1.17 9.2)))
                       (curveto ((-3.23 9.2 -4.79 7.53 -4.79 5.47)))
                       (lineto ((-4.76 . 5.11)))
                       (curveto ((-6.78 7.51 -8 10.62 -8 13.99)))
                       (curveto ((-8 18.41 -4.42 22 0 22)))
                       (curveto ((4.42 22 8 18.41 8 13.99)))
                       (curveto ((8 8.6 5.41 3.79 1.5 0.67)))
                       (closepath)
                       (moveto ((-0.29 . 19)))
                       (curveto ((-2.07 19 -3.51 17.6 -3.51 15.86)))
                       (curveto ((-3.51 14.24 -2.46 13.1 -0.7 12.74)))
                       (curveto ((1.07 12.38 2.9 11.53 3.92 10.16)))
                       (curveto ((4.31 11.45 4.51 12.81 4.51 14.2)))
                       (curveto ((4.51 16.85 2.36 19 -0.29 19)))
                       (closepath))
              :fill (emacstreak-get-color 'fire) :stroke-opacity 0)
    (emacstreak--text g-number number :x 0 :y 32 :fill (emacstreak-get-color 'currStreakNum)
                      :font-weight "700" :font-size "28px"
                      :style "animation: currstreak 0.6s linear forwards")))

(defun emacstreak--longest-streak (svg number range)
  "Draw longest streak component in SVG with NUMBER of days in RANGE."
  (let* ((g (svg-node svg 'g :style "isolation: isolate"))
         (column-width (/ emacstreak--card-width 3))
         (column-offset (+ (/ column-width 2) column-width column-width))
         (g-number (svg-node g 'g :transform (format "translate(%s, 48)" column-offset)))
         (g-label (svg-node g 'g :transform (format "translate(%s, 84)" column-offset)))
         (g-range (svg-node g 'g :transform (format "translate(%s, 114)" column-offset))))
    (emacstreak--text g-number number :x 0 :y 32 :fill (emacstreak-get-color 'sideNums)
                      :font-weight "700" :font-size "28px"
                      :style "opacity: 0; animation: fadein 0.5s linear forwards 1.2s")
    (emacstreak--text g-label "Longest Streak" :x 0 :y 32 :fill (emacstreak-get-color 'sideLabels)
                      :font-weight "400" :font-size "14px"
                      :style "opacity: 0; animation: fadein 0.5s linear forwards 1.3s")
    (emacstreak--text g-range range :x 0 :y 32 :fill (emacstreak-get-color 'dates)
                      :font-weight "400" :font-size "12px"
                      :style "opacity: 0; animation: fadein 0.5s linear forwards 1.4s")))

(defun emacstreak--format-number (number)
  "Format NUMBER as string with commas."
  (with-temp-buffer
    (insert (number-to-string number))
    (let ((p (- (point) 3)))
      (while (> p (point-min))
        (goto-char p)
        (insert ",")
        (setq p (- (point) 4))))
    (buffer-string)))

(defun emacstreak--format-date (dt current-year)
  "Format decoded time DT as string.
If in the CURRENT-YEAR, year part is omitted."
  (let ((system-time-locale "C"))
    (format-time-string
     (if (= (decoded-time-year dt) current-year)
         "%b %d"
       "%b %d, %Y")
     (encode-time dt))))

(defun emacstreak--format-range (today from to &optional is-current-streak)
  "Format range between FROM and TO.
If TO is not before TODAY and IS-CURRENT-STREAK is nil, it is shown as \"Present\"."
  (let* ((current-dt (parse-time-string (concat today "T00:00:00Z")))
         (current-year (decoded-time-year current-dt))
         (from-dt (parse-time-string (concat from "T00:00:00Z")))
         (to-dt (parse-time-string (concat to "T00:00:00Z")))
         (system-time-locale "C"))
    (cond
     ((equal from to) (emacstreak--format-date from-dt current-year))
     (t
      (concat
       (emacstreak--format-date from-dt current-year)
       " - "
       (if (or is-current-streak (string< to today))
           (emacstreak--format-date to-dt current-year)
         "Present"))))))

(defun emacstreak--svg (stats)
  "Return SVG of GitHub streak STATS."
  (let* ((today (plist-get stats :today))
         (svg (svg-create emacstreak--card-width emacstreak--card-height
                          :direction "ltr"
                          :viewBox (format "0 0 %s %s" emacstreak--card-width emacstreak--card-height)
                          :style "isolation: isolate"))
         (g (svg-node svg 'g :clip-path "url(#outer_rectangle)")))
    (setq emacstreak--last-streak-stats stats)
    (emacstreak--defs svg)
    (emacstreak--style svg)
    (emacstreak--border g)
    (emacstreak--total-contributions g
                                     (emacstreak--format-number (plist-get stats :total-contributions))
                                     (emacstreak--format-range today (plist-get stats :first-contribution) today))
    (emacstreak--current-streak g
                                (emacstreak--format-number (plist-get stats :current-streak-length))
                                (emacstreak--format-range
                                 today
                                 (plist-get stats :current-streak-start)
                                 (plist-get stats :current-streak-end)
                                 t))
    (emacstreak--longest-streak g
                                (emacstreak--format-number (plist-get stats :longest-streak-length))
                                (emacstreak--format-range
                                 today
                                 (plist-get stats :longest-streak-start)
                                 (plist-get stats :longest-streak-end)))
    svg))

(defun emacstreak-generate-svg (user)
  "Generate SVG of GitHub streak stats.
This does not store the last queried streak stats."
  (let* ((today (format-time-string "%Y-%m-%d" (current-time)))
         (stats (emacstreak--calculate-contributions user today)))
    (emacstreak--svg stats)))

(defun emacstreak-save-svg (user output-file &optional use-cache)
  "Save SVG of GitHub streak stats of USER to OUTPUT-FILE.
If USE-CACHE is non-nil, the last queried streak stats is used."
  (interactive (list
                (or (and current-prefix-arg emacstreak--last-streak-stats)
                    (read-string "User: "))
                (read-file-name "Output File: ")
                current-prefix-arg))
  (unless (and use-cache emacstreak--last-streak-stats)
    (let ((today (format-time-string "%Y-%m-%d" (current-time))))
      (setq emacstreak--last-streak-stats (emacstreak--calculate-contributions user today))))

  (let ((svg (emacstreak--svg emacstreak--last-streak-stats)))
    (with-temp-buffer
      (svg-print svg)
      (write-region (point-min) (point-max) output-file))))

(defun emacstreak-show-svg (user &optional use-cache)
  "Show SVG of GitHub streak stats of USER without animation.
If USE-CACHE is non-nil, the last queried streak stats is used.
If you want to save SVG with animation, use `emacstreak-save-svg' instead."
  (interactive (list
                (or (and current-prefix-arg emacstreak--last-streak-stats)
                    (read-string "User: "))
                current-prefix-arg))
  (unless (and use-cache emacstreak--last-streak-stats)
    (let ((today (format-time-string "%Y-%m-%d" (current-time))))
      (setq emacstreak--last-streak-stats (emacstreak--calculate-contributions user today))))

  (let ((svg (emacstreak--svg emacstreak--last-streak-stats)))
    (dolist (elem (dom-by-style svg "animation"))
      (setf (dom-attr elem 'style) nil))
    (with-current-buffer (get-buffer-create "*emacstreak*")
      (erase-buffer)
      (insert-image (svg-image svg))
      (image-mode)
      (pop-to-buffer (current-buffer)))))

(provide 'emacstreak)
;;; emacstreak.el ends here
