;;; spotemacs.el --- A package for controlling the spotify client -*- lexical-binding: t; -*-
;;
;; Copyright (C) 2021 Rudranil Sarkar
;;
;; Author: Rudranil Sarkar <https://github.com/Rudranil-Sarkar>
;; Maintainer: Rudranil Sarkar <rudronil34@gmail.com>
;; Created: November 18, 2021
;; Modified: November 18, 2021
;; Version: 0.0.1
;; Keywords: multimedia spotify
;; Homepage: https://github.com/Rudranil-Sarkar/spotemacs
;; Package-Requires: ((emacs "24.3"))
;;
;; This file is not part of GNU Emacs.
;;
;;; Commentary:
;;
;;  Description

;; A Minor mode for controlling the spotify client from emacs. You can change the playlist or control the playback of the current track.
;; You can choose the playlist interactivly and add playlist by their url. Currently the playlist adding feature is kind of a hack you have to
;; enter the url and the playlist name yourself rather than it automaticly fetches the information.
;;
;;; Code:

(eval-when-compile
  (require 'dbus))

;; vairables
(defcustom spotemacs--spotify-dbus-service "org.mpris.MediaPlayer2.spotify"
  "The name of the dbus service for spotify"
  :type 'string
  :group 'spotemacs )

(defcustom spotemacs--spotify-dbus-path "/org/mpris/MediaPlayer2"
  "The name of the dbus path for spotify"
  :type 'string
  :group 'spotemacs )

(defcustom spotemacs--spotify-dbus-interface "org.mpris.MediaPlayer2.Player"
  "The name of the dbus interface for spotify"
  :type 'string
  :group 'spotemacs )

(defcustom spotemacs-keymap-prefix "C-x C-s "
  "The prefix for spotemacs-mode keybindings"
  :type 'string
  :group 'spotemacs)

(defcustom spotemacs--cache-file (concat user-emacs-directory ".local/cache/spotemacs")
  "The location of the cache file for spotemacs"
  :type 'file
  :group 'spotemacs)

;; Internal functions

(defun spotemacs--start-spotify-process ()
  "Start the spotify desktop client process"
  (start-process "spotify" nil "spotify"))

(defun spotemacs--prompt-for-open-spotify ()
  "Asks the user to open spotify client and return their choice"
  (let ((shouldopen (y-or-n-p "Spotify Client is not running. Start Spotify: ")))
  (when shouldopen (spotemacs--start-spotify-process)) shouldopen))

(defun spotemacs--get-playlist-id (url)
  "Get the playlist id from the url"
  (elt (split-string url "[/\&?]" t) 3))

(defun spotemacs--check-client-error (func)
  "To check the status of the spotify client"
  (condition-case _
      (funcall func)
    (dbus-error
     (message "Spotify client is not running")
     ;; Return t if there is a error
     t)))

(defun spotemacs--create-cache-file ()
  "Create the cache file"
  (with-current-buffer (find-file-noselect spotemacs--cache-file t)
    (insert "()")
    (save-buffer)))

(defun spotemacs--open-cache-buffer ()
  "Open the cache file into a buffer"
  (unless (file-exists-p spotemacs--cache-file) (spotemacs--create-cache-file))
  (find-file-noselect spotemacs--cache-file t))

(defun spotemacs--add-playlist (id playlistname)
  "Insert new Playlist into the cache file"
  (with-current-buffer (spotemacs--open-cache-buffer)
    (save-excursion (goto-char (+ (point-min) 1))
                    (insert (format "(\"%s\" . \"%s\")" playlistname id))
                    (save-buffer))))

(defun spotemacs--play-playlist (playlist)
  "Play a specified playlist in spotify client"
  (spotemacs--check-client-error (lambda nil (dbus-call-method :session
                    spotemacs--spotify-dbus-service
                    spotemacs--spotify-dbus-path
                    spotemacs--spotify-dbus-interface "OpenUri"
                    (concat "spotify:playlist:" playlist)))))

(defun spotemacs--check-spotify-status ()
  "Check if the spotify client is running or not
returns t if running nil if not"
  (or (spotemacs--check-client-error  (lambda nil (dbus-ping :session spotemacs--spotify-dbus-service))) nil))

(defun spotemacs--read-cache-file ()
  "Read the playlist info from the cache file"
  (with-current-buffer (spotemacs--open-cache-buffer)
    (save-excursion (goto-char (point-min))
                    (read(thing-at-point 'list t)))))

;; User facing functions

(defun spotemacs-play-pause-track ()
  "Play or Pause the current track"
  (interactive)
  (spotemacs--check-client-error
   (lambda nil (dbus-call-method :session
                                 spotemacs--spotify-dbus-service
                                 spotemacs--spotify-dbus-path
                                 spotemacs--spotify-dbus-interface "PlayPause"))))

(defun spotemacs-next-track ()
  "Go to the next track"
  (interactive)
  (spotemacs--check-client-error
   (lambda nil (dbus-call-method :session
                                 spotemacs--spotify-dbus-service
                                 spotemacs--spotify-dbus-path
                                 spotemacs--spotify-dbus-interface "Next"))))

(defun spotemacs-prev-track ()
  "Go to the previous track"
  (interactive)
  (spotemacs--check-client-error
   (lambda nil (dbus-call-method :session
                                 spotemacs--spotify-dbus-service
                                 spotemacs--spotify-dbus-path
                                 spotemacs--spotify-dbus-interface "Previous"))))

(defun spotemacs-add-playlist (url playlist)
  (interactive "sEnter the playlist url: \nsEnter the playlist name: ")
  (let ((id (spotemacs--get-playlist-id url)))
    (spotemacs--add-playlist id playlist)))

(defun spotemacs-play-playlist (playlistid)
  "Choose and play a playlist"
  (interactive (let ((playlistAlist (spotemacs--read-cache-file)))
                 (list (assoc-default (completing-read "Choose a Playlist: " playlistAlist nil t) playlistAlist))))
    (spotemacs--play-playlist playlistid))

(defun spotemacs--key (key)
  (kbd (concat spotemacs-keymap-prefix key)))

;;;###autoload
(define-minor-mode spotemacs-mode
  "Toggles global spotemacs-mode"
  nil
  :global t
  :group 'spotemacs
  :lighter " spotemacs"
  :keymap (list (cons (spotemacs--key "p")  #'spotemacs-play-pause-track)
                (cons (spotemacs--key "n")  #'spotemacs-next-track)
                (cons (spotemacs--key "P")  #'spotemacs-prev-track)
                (cons (spotemacs--key "c")  #'spotemacs-play-playlist)
                (cons (spotemacs--key "a")  #'spotemacs-add-playlist))

  (if spotemacs-mode
      (unless (spotemacs--check-spotify-status)
        (unless (spotemacs--prompt-for-open-spotify) (setq spotemacs-mode nil)))
    (message "spotemacs mode disabled")))

(provide 'spotemacs)

;;; spotemacs.el ends here
