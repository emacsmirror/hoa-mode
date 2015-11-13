;;; hoa-mode.el --- Major mode for the Hanoi Omega Automata format

;; Copyright (C) 2015  Alexandre Duret-Lutz

;; Author: Alexandre Duret-Lutz <adl@lrde.epita.fr>
;; Version: 0.1
;; URL: https://gitlab.lrde.epita.fr/spot/emacs-modes

;; This package is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This package is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.


;;;###autoload
(add-to-list 'auto-mode-alist '("\\.hoa\\'" . hoa-mode))

;;;###autoload
(add-to-list 'magic-mode-alist '("\\<HOA:\\s-*v" . hoa-mode))

(defface hoa-header-uppercase-face
  '((t :inherit font-lock-type-face :weight bold))
  "Face for headers with an uppercase initial.")

(defface hoa-header-lowercase-face
  '((t :inherit font-lock-type-face :weight normal))
  "Face for headers with a lowercase initial.")

(defface hoa-keyword-face
  '((t :inherit font-lock-keyword-face))
  "Face used for --BODY--, --END--, and --ABORT--.")

(defface hoa-builtin-face
  '((t :inherit font-lock-builtin-face))
  "Face used for Inf, Fin, t, and f.")

(defface hoa-acceptance-set-face
  '((t :inherit font-lock-constant-face))
  "Face used for acceptance sets.")

(defface hoa-alias-face
  '((t :inherit font-lock-variable-name-face))
  "Face used for aliases.")

(defvar hoa-font-lock-keywords
  (list
   '("\\<[A-Z][a-zA-Z0-9_-]*:" . 'hoa-header-uppercase-face)
   '("\\<[a-z][a-zA-Z0-9_-]*:" . 'hoa-header-lowercase-face)
   '("@[a-zA-Z0-9_-]*\\>" . 'hoa-alias-face)
   '("\\<--\\(BODY\\|END\\|ABORT\\)--" . 'hoa-keyword-face)
   '("\\<\\(Inf\\|Fin\\|t\\|f\\)\\>" . 'hoa-builtin-face)
   '("(\\s-*\\([0-9]+\\)\\s-*)" 1 'hoa-acceptance-set-face)
   '("{\\(\\([0-9]\\|\\s-\\)+\\)}" 1 'hoa-acceptance-set-face))
  "Hilighting rules for `hoa-mode'.")

(defvar hoa-mode-syntax-table
  (let ((st (make-syntax-table)))
    (modify-syntax-entry ?_ "w" st)
    (modify-syntax-entry ?- "w" st)
    (modify-syntax-entry ?/ ". 14bn" st)
    (modify-syntax-entry ?* ". 23bn" st)
    st)
  "Syntax table for `hoa-mode'.")

(defun hoa-start-of-automaton ()
  "Move to the start of the automaton at point."
  (interactive)
  (search-backward "HOA:"))

(defun hoa-end-of-automaton ()
  "Move to the end of the automaton at point."
  (interactive)
  ; if we are pointing inside something that looks like --END-- or
  ; --ABORT--, back out a bit.
  (if (looking-at "[ENDABORT-]*-")
      (backward-word))
  (re-search-forward "--\\(END\\|ABORT\\)--\n?"))

(defun hoa-mark-current-automaton ()
  "Mark the automaton at point."
  (interactive)
  (hoa-end-of-automaton)
  (set-mark (point))
  (hoa-start-of-automaton))

(defvar hoa-display-error-buffer "*hoa-dot-error*"
  "The name of the buffer to display errors from `hoa-display-command'.")

(defvar hoa-display-buffer "*hoa-display*"
  "The name of the buffer to display automata.")

(defvar hoa-display-command "autfilt --dot='barf(Lato)' | dot -Tpng"
  "Command used to display HOA files.

The command is expected to take the automaton in HOA format on
its input stream, and output an image in PNG format on its output
stream.")

(defun hoa-display-current-automaton ()
  "Display the current automaton.

This uses the command in `hoa-display-command' to convert HOA
into png, and then display the result in `hoa-display-buffer'. If
the command terminates with an error, its standard error is put
in `hoa-display-error-buffer' and shown."
  (interactive)
  (let ((b (save-excursion (if (not (looking-at "HOA:"))
			       (hoa-start-of-automaton)
			     (point))))
	(e (save-excursion (hoa-end-of-automaton) (point)))
	(dotbuf (generate-new-buffer "*hoa-dot-output*"))
	(errfile (make-temp-file
		  (expand-file-name "hoadot" temporary-file-directory)))
	(coding-system-for-read 'no-conversion))
    (with-current-buffer dotbuf
      (set-buffer-multibyte nil))
    (let ((exit-status
	   (call-process-region b e shell-file-name nil (list dotbuf errfile)
				nil shell-command-switch hoa-display-command)))
      (when (equal 0 exit-status)
	(let ((hoa-img (create-image (with-current-buffer dotbuf (buffer-string))
				     'png t)))
	  (with-current-buffer (get-buffer-create hoa-display-buffer)
	    (erase-buffer)
	    (insert-image hoa-img)
	    (display-buffer (current-buffer)))))
      (when (file-exists-p errfile)
	(when (< 0 (nth 7 (file-attributes errfile)))
	  (with-current-buffer (get-buffer-create hoa-display-error-buffer)
	    (setq buffer-read-only nil)
	    (erase-buffer)
	    (format-insert-file errfile nil)
	    (display-buffer (current-buffer))))
	(delete-file errfile))
      (kill-buffer dotbuf))))

(defvar hoa-mode-map
  (let ((map (make-keymap)))
    (define-key map "\M-e" 'hoa-end-of-automaton)
    (define-key map "\M-a" 'hoa-start-of-automaton)
    (define-key map "\C-\M-h" 'hoa-mark-current-automaton)
    (define-key map "\C-c\C-c" 'hoa-display-current-automaton)
    map)
  "Keymap for `hoa-mode'.")

(defvar hoa-mode-hook nil
  "Hook run whenever `hoa-mode' is activated.")

(defun hoa-mode ()
  "Major mode for editing HOA files.

`http://adl.github.io/hoaf/`
"
  (interactive)
  (kill-all-local-variables)
  (set-syntax-table hoa-mode-syntax-table)
  (set (make-local-variable 'font-lock-defaults) '(hoa-font-lock-keywords))
  (use-local-map hoa-mode-map)
  (setq major-mode 'hoa-mode)
  (setq mode-name "HOA")
  (run-hooks 'hoa-mode-hook))

(provide 'hoa-mode)

;;; hoa-mode.el ends here
