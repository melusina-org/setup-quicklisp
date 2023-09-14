;;;; setup-quicklisp.lisp — Setup QuickLisp

;;;; Melusina Actions (https://github.com/melusina-org/setup-quicklisp)
;;;; This file is part of Melusina Actions.
;;;;
;;;; Copyright © 2023 Michaël Le Barbier
;;;; All rights reserved.

;;;; This file must be used under the terms of the MIT License.
;;;; This source file is licensed as described in the file LICENSE, which
;;;; you should have received as part of this distribution. The terms
;;;; are also available at https://opensource.org/licenses/MIT

(require '#:asdf)
(require '#:uiop)

(load
 (labels
     ((select-quicklisp (process)
	(uiop:run-program '("sed" "-n" "-e" "/quicklisp[.]lisp$/{s/^ *//;p;}")
			  :input (uiop:process-info-output process)
			  :output :string))
      (ubuntu-quicklisp ()
	(select-quicklisp
	 (uiop:launch-program '("dpkg" "-L" "cl-quicklisp")
                              :output :stream)))
      (macports-quicklisp ()
	(select-quicklisp
	 (uiop:launch-program '("port" "contents" "cl-quicklisp")
			      :output :stream)))
      (find-quicklisp ()
	(cond
	  ((uiop:os-macosx-p)
	   (macports-quicklisp))
	  ((uiop:os-unix-p)
	   (ubuntu-quicklisp))))
      (quicklisp-pathname ()
	(pathname (string-trim '(#\Space #\Newline #\Return #\Tab)
			       (find-quicklisp)))))
   (quicklisp-pathname)))

(defpackage #:org.melusina.lisp-action/setup-quicklisp
  (:use #:common-lisp))

(in-package #:org.melusina.lisp-action/setup-quicklisp)

(defparameter *quicklisp-home*
  (or
   (uiop:getenv "QUICKLISP_HOME")
   (merge-pathnames
    #p"quicklisp/"
    (user-homedir-pathname)))
  "Home directory for QuickLisp.")

(defparameter *quicklisp-register-local-projects*
  (if (uiop:getenv "QUICKLISP_REGISTER_LOCAL_PROJECTS")
      (not (string= (uiop:getenv "QUICKLISP_REGISTER_LOCAL_PROJECTS") "no"))
      t)
  "Flag governing registering local projects.")

(defparameter *quicklisp-additional-systems*
  (when (uiop:getenv "QUICKLISP_ADDITIONAL_SYSTEMS")
    (uiop:split-string (uiop:getenv "QUICKLISP_ADDITIONAL_SYSTEMS")))
  "List of additional packages to install.")

(defun write-detail (&key name key value)
  "Write detail NAME with VALUE.
Additionally, when running on GitHub Actions, the key is written
to job output."
  (format t "~&~A: ~A~%" name value)
  (when (uiop:getenv "GITHUB_OUTPUT")
    (with-open-file (output (uiop:getenv "GITHUB_OUTPUT")
			    :direction :output
			    :if-exists :append :if-does-not-exist :create)
      (format output "~&~A=~A~%" key value))))

(defun install-quicklisp ()
  (quicklisp-quickstart:install :path *quicklisp-home*)
  (eval
   (list
    (find-symbol "WITHOUT-PROMPTING" "QL-UTIL")
    (list (find-symbol "ADD-TO-INIT-FILE" "QL")))))

(defun register-local-projects ()
  (when *quicklisp-register-local-projects*
    (let ((workspace
	    (uiop:getenv "GITHUB_WORKSPACE"))
	  (init-file
	    (merge-pathnames
	     (funcall
	      (find-symbol "INIT-FILE-NAME" "QL-IMPL-UTIL"))
	     (user-homedir-pathname))))
      (when workspace
	(pushnew (pathname workspace)
		 (symbol-value (find-symbol "*LOCAL-PROJECT-DIRECTORIES*" "QL")))
	(with-open-file (output init-file
				:direction :output
				:if-exists :append :if-does-not-exist :create)
	  (format output "~&#+quicklisp~&(pushnew #p~S ql:*local-project-directories*)"
		  workspace))))
    (funcall (find-symbol "REGISTER-LOCAL-PROJECTS" "QL"))))

(defun load-additional-systems ()
  (when *quicklisp-additional-systems*
    (funcall
     (find-symbol "QUICKLOAD" "QL")
     *quicklisp-additional-systems*)))

(defun write-quicklisp-details ()
  "Write details about the current Common Lisp Implementation."
  (write-detail
   :name "QuickLisp Home"
   :key "quicklisp-home"
   :value *quicklisp-home*))

(progn
  (install-quicklisp)
  (register-local-projects)
  (load-additional-systems)
  (write-quicklisp-details))

;;;; End of file `setup-quicklisp.lisp'
