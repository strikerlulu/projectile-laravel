(eval-when-compile (require 'cl-lib))
(require 'projectile)
(require 'inflections)
(require 'transient)
(require 'json)

(defgroup projectile-laravel nil
  "Laravel mode based on projectile"
  :prefix "projectile-laravel-"
  :group 'projectile)

;; TODO from where do i scrape this keywords correctly ?
(defcustom projectile-laravel-controller-keywords
  '("logger" "polymorphicPath" "polymorphicUrl" "mail" "render" "attachments"
    "default" "helper" "helperAttr" "helperMethod" "layout" "urlFor"
    "serialize" "exempt_from_layout" "filter_parameter_logging" "hideAction"
    "prepend_around_action" "skip_before_action" "skip_after_action" "skip_action")
  "List of keywords to highlight for controllers."
  :group 'projectile-laravel
  :type '(repeat string))

(defcustom projectile-laravel-migration-keywords
  '("createTable" "changeTable" "drop_table" "renameTable" "addColumn"
    "renameColumn" "changeColumn" "changeColumnDefault" "changeColumnNull"
    "removeColumn" "addIndex" "removeIndex" "renameIndex" "execute"
    "addTimestamps" "removeTimestamps" "add_foreign_key" "removeForeignKey"
    "addReference" "removeReference" "addBelongsTo" "remove_belongs_to"
    "transaction" "reversible" "revert" "announce")
  "List of keywords to highlight for migrations."
  :group 'projectile-laravel
  :type '(repeat string))

(defcustom projectile-laravel-model-keywords
  '("defaultScope" "namedScope" "scope" "serialize" "belongsTo" "hasOne"
    "hasMany" "hasAndBelongsToMany" "composed_of" "acceptsNestedAttributesFor"
    "beforeCreate" "before_destroy" "before_save" "beforeUpdate" "beforeValidation"
    "beforeValidationOnCreate" "beforeValidationOnUpdate" "afterCreate"
    "validatesExistenceOf" "validates_uniqueness_of" "validates_with"
    "enum" "after_create_commit" "after_update_commit" "after_destroy_commit")
  "List of keywords to highlight for models."
  :group 'projectile-laravel
  :type '(repeat string))

(defcustom projectile-laravel-view-keywords
  '("action_name" "atom_feed" "audio_path" "audio_tag" "auto_discovery_link_tag"
    "button_tag" "button_to" "button_to_function" "cache" "capture" "cdata_section"
    "time_ago_in_words" "time_select" "time_tag" "time_zone_options_for_select"
    "time_zone_select" "translate" "truncate" "url_field" "url_field_tag"
    "url_for" "url_options" "video_path" "video_tag" "word_wrap")
  "List of keywords to highlight for views."
  :group 'projectile-laravel
  :type '(repeat string))

(defcustom projectile-laravel-active-support-keywords
  '("alias_attribute" "with_options" "delegate")
  "List of keywords to highlight for all `projectile-laravel-mode' buffers."
  :group 'projectile-laravel
  :type '(repeat string))

(defvar projectile-laravel-keyword-face 'projectile-laravel-keyword-face
  "Face name to use for keywords.")

(defface projectile-laravel-keyword-face '((t :inherit 'font-lock-keyword-face))
  "Face to be used for higlighting the laravel keywords."
  :group 'projectile-laravel)

(defcustom projectile-laravel-views-re
  (concat "\\."
          (regexp-opt '("html" "erb" "haml" "slim"
                        "php"
                        "js" "coffee" "ts"
                        "css" "scss" "less"
                        "json" "builder" "jbuilder" "rabl")))
  "Regexp for filtering for view files."
  :group 'projectile-laravel
  :type 'regexp)

(defcustom projectile-laravel-javascript-re
  "\\.js\\(?:\\.\\(?:coffee\\|ts\\)\\)?\\'"
  "Regexp for filtering for Javascript/altJS files."
  :group 'projectile-laravel
  :type 'regexp)

(defcustom projectile-laravel-stylesheet-re
  "\\.css\\(?:\\.\\(?:scss\\|sass\\|less\\)\\)?\\'"
  "Regexp for filtering for stylesheet files."
  :group 'projectile-laravel
  :type 'regexp)

(defcustom projectile-laravel-errors-re
  "\\([0-9A-Za-z@_./\:-]+\\.php\\):?\\([0-9]+\\)?"
  "The regex used to find errors with file paths."
  :group 'projectile-laravel
  :type 'regexp)

(defcustom projectile-laravel-generate-filepath-re
  "^\\s-+\\(?:create\\|exists\\|conflict\\|skip\\)\\s-+\\(.+\\)$"
  "The regex used to find file paths in `projectile-laravel-generate-mode'."
  :group 'projectile-laravel
  :type 'regexp)

(defcustom projectile-laravel-javascript-dirs
  '("resources/js/" "public/js/")
  "The list of directories to look for the javascript files in."
  :group 'projectile-laravel
  :type '(repeat string))

(defcustom projectile-laravel-component-dir "app/javascript/packs/"
  "The directory to look for javascript component files in."
  :group 'projectile-laravel
  :type 'string)

(defcustom projectile-laravel-stylesheet-dirs
  '("resources/css/" "public/css/")
  "The list of directories to look for the stylesheet files in."
  :group 'projectile-laravel
  :type '(repeat string))

(defcustom projectile-laravel-add-keywords t
  "If not nil the laravel keywords will be font locked in the mode's bufffers."
  :group 'projectile-laravel
  :type 'boolean)

(defcustom projectile-laravel-keymap-prefix nil
  "Keymap prefix for `projectile-laravel-mode'."
  :group 'projectile-laravel
  :type 'string)

(defcustom projectile-laravel-server-mode-ansi-colors t
  "If not nil `projectile-laravel-server-mode' will apply the ansi colors in its buffer."
  :group 'projectile-laravel
  :type 'boolean)

(defcustom projectile-laravel-discover-bind "s-r"
  "The :bind option that will be passed `discover-add-context-menu' if available."
  :group 'projectile-laravel
  :type 'string)

(defcustom projectile-laravel-root-file "artisan"
  "The file that is used to identify laravel root."
  :group 'projectile-laravel
  :type 'string)

(defcustom projectile-laravel-verify-root-files '("routes/web.php" "artisan")
  "The list of files that is used to verify laravel root directory.
When any of the files are found it means that this is a laravel app."
  :group 'projectile-laravel
  :type 'string)

(define-obsolete-variable-alias 'projectile-laravel-verify-root-file 'projectile-laravel-verify-root-files)

(defcustom projectile-laravel-custom-console-command "php artisan tinker"
  "When set it will be used instead of a preloader as the command for running console."
  :group 'projectile-laravel
  :type 'string)

(defcustom projectile-laravel-custom-dbconsole-command "php artisan db"
  "When set it will be used instead of a preloader as the command for running dbconsole."
  :group 'projectile-laravel
  :type 'string)

;;NOTE changed custom
(defcustom projectile-laravel-custom-server-command "php artisan serve"
  "When set it will be used instead of a preloader as the command for running server."
  :group 'projectile-laravel
  :type 'string)

(defcustom projectile-laravel-custom-generate-command "php artisan make"
  "When set it will be used instead of a preloader as the command for running generate."
  :group 'projectile-laravel
  :type 'string)

(defcustom projectile-laravel-custom-destroy-command "php artisan down"
  "When set it will be used instead of a preloader as the command for running destroy."
  :group 'projectile-laravel
  :type 'string)

(defvar projectile-laravel-server-buffer-name "*projectile-laravel-server*")
(defvar projectile-laravel-composer-install-buffer-name "*projectile-laravel-composer-install*")
(defvar projectile-laravel-npm-install-buffer-name "*projectile-laravel-npm-install*")
(defvar projectile-laravel-npm-watch-buffer-name "*projectile-npm-watch*")

(defvar projectile-laravel-generators
  '(("assets" (("app/assets/"
                "app/assets/\\(?:stylesheets\\|javascripts\\)/\\(.+?\\)\\..+$")))
    ("controller" (("app/Http/Controllers/" "app/Http/Controllers/\\(.+\\)Controller\\.php$")))
    ("generator" (("lib/generator/" "lib/generators/\\(.+\\)$")))
    ("helper" (("app/helpers/" "app/helpers/\\(.+\\)_helper.php$")))
    ("integration_test" (("test/integration/" "test/integration/\\(.+\\)_test\\.php$")))
    ("job" (("app/jobs/" "app/jobs/\\(.+\\)_job\\.php$")))
    ("mailer" (("app/mailers/" "app/mailers/\\(.+\\)\\.php$")))
    ("migration" (("database/migrations/" "database/migrations/[0-9]+_\\(.+\\)\\.php$")))
    ("model" (("app/Models/" "app/Models/\\(.+\\)\\.php$")))
    ("resource" (("app/Models/" "app/Models/\\(.+\\)\\.php$")))
    ("scaffold" (("app/Models/" "app/Models/\\(.+\\)\\.php$")))
    ("task" (("lib/tasks/" "lib/tasks/\\(.+\\)\\.rake$")))))

(defun projectile-laravel--command (&rest cases)
  "Check for the presence of pre-loaders and return corresponding value.

CASES is a plist with props being :spring, :zeus or :vanilla.
Each corresponds to a preloader (:vanilla means no preloader).
If a preloader is running the value for the given prop is returned."
  (let ((custom-command (plist-get cases :custom)))
    (cond
     (custom-command
      (projectile-laravel--ensure-suffix custom-command " "))
     ((projectile-laravel-spring-p)
      (plist-get cases :spring))
     ((projectile-laravel-zeus-p)
      (plist-get cases :zeus))
     (t
      (plist-get cases :vanilla)))))

(defalias 'projectile-laravel-with-preloader 'projectile-laravel--command)

(defmacro projectile-laravel-with-root (body-form)
  "Run BODY-FORM within DEFAULT-DIRECTORY set to `projectile-laravel-root'."
  `(let ((default-directory (projectile-laravel-root)))
     ,body-form))

(defmacro projectile-laravel-find-current-resource (dir re fallback)
  "RE will be the argument to `s-lex-format'.

The bound variables are \"singular\" and \"plural\".
Argument DIR is the directory to which the search should be narrowed."
  `(let* ((singular (projectile-laravel-current-resource-name))
          (plural (inflection-pluralize-string singular))
          (abs-current-file (buffer-file-name (current-buffer)))
          (current-file (if abs-current-file
                            (file-relative-name abs-current-file
                                                (projectile-laravel-root))))
          (choices (projectile-laravel-choices
                    (list (list ,dir (s-lex-format ,re)))))
          (files (projectile-laravel-hash-keys choices)))
     (if (eq files ())
         (funcall ,fallback)
       (projectile-laravel-goto-file
        (if (= (length files) 1)
            (gethash (-first-item files) choices)
          (projectile-laravel--choose-file-or-new choices files))))))

(defun projectile-laravel--choose-file-or-new (choices files)
  (let* ((choice (projectile-completing-read "Which exactly: " files))
         (candidate (gethash choice choices)))
    (if (f-exists? (projectile-laravel-expand-root candidate))
        candidate
      (concat (f-dirname (gethash (-first-item files) choices)) choice))))

(defun projectile-laravel-highlight-keywords (keywords)
  "Highlight the passed KEYWORDS in current buffer."
  (font-lock-add-keywords
   nil
   (list (list
          (concat "\\(^\\|[^_:.@$]\\|\\.\\.\\)\\b"
                  (regexp-opt keywords t)
                  "\\_>")
          (list 2 'projectile-laravel-keyword-face)))))

(defun projectile-laravel-add-keywords-for-file-type ()
  "Apply extra font lock keywords specific to models, controllers etc."
  (cl-loop for (re keywords) in `(("Controller\\.php$"   ,projectile-laravel-controller-keywords)
                                  ("app/Models/.+\\.php$" ,projectile-laravel-model-keywords)
                                  ("database/migrations/.+\\.php$" ,projectile-laravel-migration-keywords))
           do (when (and (buffer-file-name) (string-match-p re (buffer-file-name)))
                (projectile-laravel-highlight-keywords
                 (append keywords projectile-laravel-active-support-keywords)))))

(defun projectile-laravel-dir-files (directory)
  "Wrapper around `projectile-dir-files', list the files in DIRECTORY and in its sub-directories.

Files are returned as relative paths to DIRECTORY. This function was created to handle the case when laravel is inside a
subdirectory, but nowadays it does nothing as `projectile-dir-files' does the right thing."
  (projectile-dir-files directory))

(defun projectile-laravel-choices (dirs)
  "Uses `projectile-laravel-dir-files' function to find files in directories.

The DIRS is list of lists consisting of a directory path and regexp to filter files from that directory.
Optional third element can be present in the DIRS list. The third element will be a prefix to be placed before
the filename in the resulting choice.
Returns a hash table with keys being short names (choices) and values being relative paths to the files."
  (let ((hash (make-hash-table :test 'equal)))
    (cl-loop for (dir re prefix) in dirs do
             (cl-loop for file in (projectile-laravel-dir-files (projectile-laravel-expand-root dir)) do
                      (when (string-match re file)
                        (puthash
                         (concat (or prefix "") (match-string 1 file))
                         (concat dir file)
                         hash))))
    hash))

(defun projectile-laravel-hash-keys (hash)
  "Return the keys in HASH."
  (if (boundp 'hash-table-keys)
      (hash-table-keys hash)
    (let (keys)
      (maphash (lambda (key value) (setq keys (cons key keys))) hash)
      keys)))

(defmacro projectile-laravel-find-resource (prompt dirs &optional newfile-template)
  "Presents files from DIRS with PROMPT to the user using `projectile-completing-read'.

If users chooses a non existant file and NEWFILE-TEMPLATE is not nil
it will use that variable to interpolate the name for the new file.
NEWFILE-TEMPLATE will be the argument for `s-lex-format'.
The bound variable is \"filename\"."
  `(let ((choices (projectile-laravel-choices ,dirs)))
     (projectile-completing-read
      ,prompt
      (projectile-laravel-hash-keys choices)
      :action (lambda (c)
                (let* ((filepath (gethash c choices))
                       (filename c)) ;; so `s-lex-format' can interpolate FILENAME
                  (if filepath
                      (projectile-laravel-goto-file filepath)
                    (when ,newfile-template
                      (projectile-laravel-goto-file (s-lex-format ,newfile-template) t))))))))

(defun projectile-laravel-find-model ()
  "Find a model."
  (interactive)
  (projectile-laravel-find-resource
   "model: "
   '(("app/Models/" "\\(.+\\)\\.php$"))
   "app/Models/${filename}.php"))

(defun projectile-laravel-find-controller ()
  "Find a controller."
  (interactive)
  (projectile-laravel-find-resource
   "controller: "
   '(("app/Http/Controllers/" "\\(.+?\\)\\(Controller\\)?\\.php$"))
   "app/Http/Controllers/${filename}Controller.php"))

(defun projectile-laravel-find-view ()
  "Find a template or a partial."
  (interactive)
  (projectile-laravel-find-resource
   "view: "
   `(("resources/views/" ,(concat "\\(.+\\)" projectile-laravel-views-re)))
   "resources/views/${filename}"))

(defun projectile-laravel-find-layout ()
  "Find a layout file."
  (interactive)
  (projectile-laravel-find-resource
   "layout: "
   `(("resources/views/layouts/" ,(concat "\\(.+\\)" projectile-laravel-views-re)))
   "resources/views/layouts/${filename}"))

(defun projectile-laravel-find-helper ()
  "Find a helper."
  (interactive)
  (projectile-laravel-find-resource
   "helper: "
   '(("app/helpers/" "\\(.+\\)_helper\\.php$"))
   "app/helpers/${filename}_helper.php"))

(defun projectile-laravel-find-public-storage ()
  "Find a file within lib directory."
  (interactive)
  (projectile-laravel-find-resource
   "storage: "
   '(("storage/app/public/" "\\(.+\\)"))
   "storage/app/public/${filename}"))

(defun projectile-laravel-find-config ()
  "Find a spec."
  (interactive)
  (projectile-laravel-find-resource
   "config: "
   '(("config/" "\\(.+\\)\\.php$"))
   "config/${filename}.php"))

(defun projectile-laravel-find-test ()
  "Find a test."
  (interactive)
  (projectile-laravel-find-resource
   "test: "
   '(("tests/" "\\(.+\\)Test\\.php$"))
   "tests/${filename}Test.php"))

(defun projectile-laravel-find-feature-tests ()
  "Find a feature file."
  (interactive)
  (projectile-laravel-find-resource
   "feature: "
   '(("tests/Feature/" "\\(.+\\)\\.Test$"))
   "tests/Feature/${filename}.Test"))

(defun projectile-laravel-find-migration ()
  "Find a migration."
  (interactive)
  (projectile-laravel-find-resource "migration: " '(("database/migrations/" "\\(.+\\)\\.php$"))))

(defun projectile-laravel-find-seeder ()
  "Find a seeders."
  (interactive)
  (projectile-laravel-find-resource "seeder: " '(("database/seeders/" "\\(.+\\)\\.php$"))))

(defun projectile-laravel-find-factory ()
  "Find a factory."
  (interactive)
  (projectile-laravel-find-resource "factory: " '(("database/factories/" "\\(.+\\)\\.php$"))))

(defun projectile-laravel-find-middleware ()
  "Find a middlware."
  (interactive)
  (projectile-laravel-find-resource "middleware: " '(("app/Http/Middleware/" "\\(.+\\)\\.php$"))))

;;FIXME it collides with the command find-resource
(defun projectile-laravel-find-model-resource ()
  "Find a resource."
  (interactive)
  (projectile-laravel-find-resource "resource: " '(("app/Http/Resources/" "\\(.+\\)\\.php$"))))

(defun projectile-laravel-find-javascript ()
  "Find a javascript file."
  (interactive)
  (projectile-laravel-find-resource
   "javascript: "
   (--map (list it "\\(.+\\)\\.[^.]+$") projectile-laravel-javascript-dirs)))

(defun projectile-laravel-find-component ()
  "Find a javascript component."
  (interactive)
  (projectile-laravel-find-resource
   "component: "
   `((,projectile-laravel-component-dir "\\(.+\\.[^.]+\\)$"))))

(defun projectile-laravel-find-stylesheet ()
  "Find a stylesheet file."
  (interactive)
  (projectile-laravel-find-resource
   "stylesheet: "
   (--map (list it "\\(.+\\)\\.[^.]+$") projectile-laravel-stylesheet-dirs)) )

(defun projectile-laravel-find-initializer ()
  "Find an initializer file."
  (interactive)
  (projectile-laravel-find-resource
   "initializer: "
   '(("config/initializers/" "\\(.+\\)\\.php$"))
   "config/initializers/${filename}.php"))

(defun projectile-laravel-find-webpack ()
  "Find a webpack configuration."
  (interactive)
  (projectile-laravel-find-resource
   "webpack config: "
   '(("config/webpack/" "\\(.+\\.[^.]+\\)$"))))

(defun projectile-laravel-find-locale ()
  "Find a locale file."
  (interactive)
  (projectile-laravel-find-resource
   "locale: "
   '(("resources/lang/"
      "\\(.+\\)\\.\\(?:php\\|yml\\)$"))
   "resources/lang/${filename}"))

(defun projectile-laravel-find-mailer ()
  "Find a mailer."
  (interactive)
  (projectile-laravel-find-resource
   "mailer: "
   '(("app/mailers/" "\\(.+\\)\\.php$"))
   "app/mailer/${filename}.php"))

(defun projectile-laravel-find-validator ()
  "Find a validator."
  (interactive)
  (projectile-laravel-find-resource
   "validator: "
   '(("app/validators/" "\\(.+?\\)\\(_validator\\)?\\.php\\'"))
   "app/validators/${filename}_validator.php"))

(defun projectile-laravel-find-job ()
  "Find a job file."
  (interactive)
  (projectile-laravel-find-resource
   "job: "
   '(("app/jobs/" "\\(.+?\\)\\(_job\\)?\\.php\\'"))
   "app/jobs/${filename}_job.php"))

(defun projectile-laravel-find-provider ()
  "Find a provider file."
  (interactive)
  (projectile-laravel-find-resource
   "provider: "
   '(("app/Providers/" "\\(.+?\\)\\(Provider\\)?\\.php\\'"))
   "app/Providers/${filename}Provider.php"))

(defun projectile-laravel-find-current-model ()
  "Find a model for the current resource."
  (interactive)
  (projectile-laravel-find-current-resource "app/Models/"
                                            "${singular}\\.php$"
                                            'projectile-laravel-find-model))

(defun projectile-laravel-find-current-controller ()
  "Find a controller for the current resource."
  (interactive)
  (projectile-laravel-find-current-resource "app/Http/Controllers/"
                                            "\\(.*${plural}\\)Controller\\.php$"
                                            'projectile-laravel-find-controller))

(defun projectile-laravel-find-current-serializer ()
  "Find a serializer for the current resource."
  (interactive)
  (projectile-laravel-find-current-resource "app/serializers/"
                                            "\\(.*${singular}\\)_serializer\\.php$"
                                            'projectile-laravel-find-serializer))

(defun projectile-laravel-find-current-view ()
  "Find a template for the current resource."
  (interactive)
  (projectile-laravel-find-current-resource "resources/views/"
                                            "${plural}/\\(.+\\)$"
                                            'projectile-laravel-find-view))

(defun projectile-laravel-find-current-helper ()
  "Find a helper for the current resource."
  (interactive)
  (projectile-laravel-find-current-resource "app/helpers/"
                                            "\\(${plural}_helper\\)\\.php$"
                                            'projectile-laravel-find-helper))

(defun projectile-laravel-find-current-seeder ()
  "Find a helper for the current resource."
  (interactive)
  (projectile-laravel-find-current-resource "database/seeders/"
                                            "\\(${singular}Seeder\\)\\.php$"
                                            'projectile-laravel-find-helper))

(defun projectile-laravel-find-current-factory ()
  "Find a helper for the current resource."
  (interactive)
  (projectile-laravel-find-current-resource "database/factories/"
                                            "\\(${singular}Factory\\)\\.php$"
                                            'projectile-laravel-find-helper))

;;FIXME it collides with the command find-current-resource
(defun projectile-laravel-find-current-model-resource ()
  "Find a helper for the current resource."
  (interactive)
  (projectile-laravel-find-current-resource "app/Http/Resources/"
                                            "\\(${singular}Resource\\)\\.php$"
                                            'projectile-laravel-find-helper))

(defun projectile-laravel-find-current-javascript ()
  "Find a javascript for the current resource."
  (interactive)
  (projectile-laravel-find-current-resource "app/assets/javascripts/"
                                            "\\(.*${plural}\\)${projectile-laravel-javascript-re}"
                                            'projectile-laravel-find-javascript))

(defun projectile-laravel-find-current-stylesheet ()
  "Find a stylesheet for the current resource."
  (interactive)
  (projectile-laravel-find-current-resource "app/assets/stylesheets/"
                                            "\\(.*${plural}\\)${projectile-laravel-stylesheet-re}"
                                            'projectile-laravel-find-stylesheet))

(defun projectile-laravel-find-current-test ()
  "Find a test for the current resource."
  (interactive)
  (projectile-toggle-between-implementation-and-test))

(defun projectile-laravel-find-current-migration ()
  "Find a migration for the current resource."
  (interactive)
  (projectile-laravel-find-current-resource "database/migrations/"
                                            "[0-9]\\{14\\}.*_\\(${plural}\\|${singular}\\).*\\.php$"
                                            ;;TODO find the regex
                                            ;; "[0-9|_]\\{17\\}.*_\\(${plural}\\|${singular}\\).*\\table.php$"
                                            'projectile-laravel-find-migration))

(defcustom projectile-laravel-resource-name-re-list
  `("/app/Models/\\(?:.+/\\)?\\(.+\\)\\.php\\'"
    "/app/Http/Controllers/\\(?:.+/\\)?\\(.+\\)Controller\\.php\\'"
    "/resources/views/\\(?:.+/\\)?\\([^/]+\\)/[^/]+\\'"
    "/app/helpers/\\(?:.+/\\)?\\(.+\\)_helper\\.php\\'"
    ,(concat "/app/assets/javascripts/\\(?:.+/\\)?\\(.+\\)" projectile-laravel-javascript-re)
    ,(concat "/app/assets/stylesheets/\\(?:.+/\\)?\\(.+\\)" projectile-laravel-stylesheet-re)
    "/database/migrations/.*create_\\(.+\\)\\.php\\'"
    "/test/.*/\\([a-z_]+?\\)\\(?:Controller\\)?_test\\.php\\'"
    "/\\(?:test\\|spec\\)/\\(?:fixtures\\|factories\\|fabricators\\)/\\(.+?\\)\\(?:_fabricator\\)?\\.\\(?:yml\\|rb\\)\\'")
  "List of regexps for extracting a resource name from a buffer file name."
  :group 'projectile-laravel
  :type '(repeat regexp))

(defun projectile-laravel-current-resource-name ()
  "Return a resource name extracted from the name of the currently visiting file."
  (let* ((file-name (buffer-file-name))
         (name (and file-name
                    (cl-loop for re in projectile-laravel-resource-name-re-list
                             do (if (string-match re file-name)
                                    (cl-return (match-string 1 file-name)))))))
    (and name
         (inflection-singularize-string name))))

(defun projectile-laravel-list-entries (fun dir)
  "Call FUN on DIR being a relative directory within a laravel project.

It is suspected that the result of FUN will be a list of filepaths.
Each filepath will have the path to the project discarded."
  (--map
   (substring it (length (concat (projectile-laravel-root) dir)))
   (funcall fun (projectile-laravel-expand-root dir))))

(defun projectile-laravel-find-log ()
  "Find a log file.

The opened buffer will have `auto-revert-tail-mode' turned on."
  (interactive)
  (let ((logs-dir (cl-loop for dir in '("storage/logs/" "spec/dummy/log/" "test/dummy/log/")
                           until (projectile-laravel--file-exists-p dir)
                           finally return dir)))

    (unless logs-dir
      (user-error "No log directory found"))

    ;;logs tend to not be under scm so do not resort to projectile-dir-files
    (find-file (projectile-laravel-expand-root
                (concat
                 logs-dir
                 (projectile-completing-read
                  "log: "
                  (projectile-laravel-list-entries 'f-files logs-dir)))))
    (auto-revert-tail-mode +1)
    (setq-local auto-revert-verbose nil)
    (buffer-disable-undo)
    (projectile-laravel-on)))

(defvar projectile-laravel-cache-data
  (make-hash-table :test 'equal)
  "A hash table that is used for caching information about the current project.")

(defun projectile-laravel-cache-key (key)
  "Generate a cache key based on the current directory and the given KEY."
  (format "%s-%s" default-directory key))

(defun projectile-laravel--laravel-app-p (root)
  "Returns t if any of the relative files in `projectile-laravel-verify-root-files' is found.
ROOT is used to expand the relative files."
  (--any-p
   (file-exists-p (expand-file-name it root))
   (-list projectile-laravel-verify-root-files)))

(defun projectile-laravel-root ()
  "Return laravel root directory if this file is a part of a Laravel application else nil."
  (let* ((cache-key (projectile-laravel-cache-key "root"))
         (cache-value (gethash cache-key projectile-laravel-cache-data)))
    (or cache-value
        (ignore-errors
          (let ((root (projectile-locate-dominating-file default-directory projectile-laravel-root-file)))
            (when (projectile-laravel--laravel-app-p root)
              (puthash cache-key root projectile-laravel-cache-data)
              root))))))

(defun projectile-laravel-root-relative-to-project-root ()
  "Return the location of the laravel root relative to `projectile-project-root'."
  (let ((laravel-root (file-truename (projectile-laravel-root)))
        (project-root (projectile-project-root)))
    (if (string-equal laravel-root project-root)
        ""
      (substring laravel-root (length (f-common-parent (list laravel-root project-root)))))))

(defun projectile-laravel-expand-root (dir)
  "Like `projectile-expand-root' (expands DIR) but consider `projectile-laravel-root'."
  (projectile-expand-root (concat (projectile-laravel-root) dir)))

(defun projectile-laravel--file-exists-p (filepath)
  "Return t if relative FILEPATH exists within current project."
  (file-exists-p (projectile-laravel-expand-root filepath)))

(defun projectile-laravel-artisan (arg)
  "Start a laravel console, asking for which if ARG is not nil."
  (interactive "P")
  (projectile-laravel-with-root
   (switch-to-buffer (make-comint-in-buffer "artisan" "artisan" "php" nil "artisan" "tinker"))
   ;; (+eshell/here "php artisan tinker")
   )
  (projectile-laravel-mode +1))

(defun projectile-laravel-dbconsole (arg)
  "Run laravel artisan db command. "
  (interactive "P")
  (projectile-laravel-with-root
   (switch-to-buffer (make-comint-in-buffer "dbconsole" "dbconsole" "php" nil "artisan" "db")))
  (projectile-laravel-mode +1))

(defun projectile-laravel--goto-file-at-point (f)
  "Let name and line variables and call F."
  (let ((name (projectile-laravel-name-at-point))
        (line (projectile-laravel-current-line))
        (case-fold-search nil))
    (funcall f name line)))

(defun projectile-laravel--views-goto-file-at-point (name line)
  (cond
   (
    (string-match-p "view(.*)" "view('components.order-item')")
    ;; (string-match-p "\\_<render\\_>" line)
    (projectile-laravel-goto-template-at-point) t)

   ((string-match-p "\\_<javascript_include_tag\\_>" line)
    (projectile-laravel-goto-asset-at-point projectile-laravel-javascript-dirs) t)

   ((string-match-p "\\_<stylesheet_link_tag\\_>" line)
    (projectile-laravel-goto-asset-at-point projectile-laravel-stylesheet-dirs) t)))

(defun projectile-laravel--stylesheet-goto-file-at-point (name line)
  (cond
   ((string-match-p "^\\s-*\\*= require .+\\s-*$" line)
    (projectile-laravel-goto-asset-at-point projectile-laravel-stylesheet-dirs) t)

   ((string-match-p "^\\s-*\\@import .+\\s-*$" line)
    (projectile-laravel-goto-asset-at-point projectile-laravel-stylesheet-dirs) t)))

(defun projectile-laravel--javascript-goto-file-at-point (name line)
  (cond
   ((string-match-p "^\\s-*//= require .+\\s-*$" line)
    (projectile-laravel-goto-asset-at-point projectile-laravel-javascript-dirs) t)

   ((string-match-p "^\\s-*\\#= require .+\\s-*$" line)
    (projectile-laravel-goto-asset-at-point projectile-laravel-javascript-dirs) t)))

(defun projectile-laravel--php-goto-file-at-point (name line)
  (cond
   ((string-match-p "\\_<require_relative\\_>" line)
    (projectile-laravel-ff (expand-file-name (concat (thing-at-point 'filename) ".php"))) t)

   ((string-match-p "\\_<require\\_>" line)
    (projectile-laravel-goto-gem (thing-at-point 'filename)) t)

   ((string-match-p "\\_<gem\\_>" line)
    (projectile-laravel-goto-gem (thing-at-point 'filename)) t)

   ((string-match-p "^[a-z]" name)
    (projectile-laravel-find-constant (inflection-singularize-string name)) t)

   ((string-match-p "^\\(::\\)?[A-Z]" name)
    (projectile-laravel-goto-constant-at-point) t)))

;;;###autoload
(defun projectile-laravel-views-goto-file-at-point ()
  "Try to find a view file at point.
Will try to look for a template or partial file, and assets file."
  (interactive)
  (projectile-laravel--goto-file-at-point
   'projectile-laravel--views-goto-file-at-point))

;;;###autoload
(defun projectile-laravel-stylesheet-goto-file-at-point ()
  "Try to find stylesheet file at point."
  (interactive)
  (projectile-laravel--goto-file-at-point
   'projectile-laravel--stylesheet-goto-file-at-point))

;;;###autoload
(defun projectile-laravel-javascript-goto-file-at-point ()
  "Try to find javascript file at point."
  (interactive)
  (projectile-laravel--goto-file-at-point
   'projectile-laravel--javascript-goto-file-at-point))

;;;###autoload
(defun projectile-laravel-php-goto-file-at-point ()
  "Try to find ruby file at point."
  (interactive)
  (projectile-laravel--goto-file-at-point
   'projectile-laravel--php-goto-file-at-point))

;;;###autoload
(defun projectile-laravel-goto-file-at-point ()
  "Try to find file at point."
  (interactive)
  (projectile-laravel--goto-file-at-point
   (lambda (name line)
     (cl-loop for f in '(projectile-laravel--stylesheet-goto-file-at-point
                         projectile-laravel--javascript-goto-file-at-point
                         projectile-laravel--views-goto-file-at-point
                         projectile-laravel--php-goto-file-at-point)
              thereis (funcall f name line)))))

(defun projectile-laravel-classify (name)
  "Split NAME by '/' character and classify each of the element."
  (--map (replace-regexp-in-string "_" "" (upcase-initials it)) (split-string name "/")))

(defun projectile-laravel-declassify (name)
  "Convert NAME to a relative filepath."
  (let ((case-fold-search nil))
    (downcase
     (replace-regexp-in-string
      "::" "/"
      (replace-regexp-in-string
       " " "_"
       (replace-regexp-in-string
        "\\([a-z]\\)\\([A-Z]\\)" "\\1 \\2" name))))))

(defun projectile-laravel-server ()
  "Run laravel server command."
  (interactive)
  (when (not (projectile-laravel--file-exists-p ".env"))
    (user-error "You're not running it from a laravel application"))
  (if (member projectile-laravel-server-buffer-name (mapcar 'buffer-name (buffer-list)))
      (switch-to-buffer projectile-laravel-server-buffer-name)
    (projectile-laravel-with-root
     (compile projectile-laravel-custom-server-command
              'projectile-laravel-server-mode))))

(defun projectile-laravel-composer-install ()
  "Run composer install command."
  (interactive)
  (when (not (projectile-laravel--file-exists-p "composer.json"))
    (user-error "There is no composerl.json file"))
  (if (member projectile-laravel-composer-install-buffer-name (mapcar 'buffer-name (buffer-list)))
      (switch-to-buffer projectile-laravel-composer-install-buffer-name)
    (projectile-laravel-with-root
     (compile "composer install"
              'projectile-laravel-composer-install-mode))))

(defun projectile-laravel-npm-install ()
  "Run npm install command."
  (interactive)
  (when (not (projectile-laravel--file-exists-p "package.json"))
    (user-error "There is no package.json file"))
  (if (member projectile-laravel-npm-install-buffer-name (mapcar 'buffer-name (buffer-list)))
      (switch-to-buffer projectile-laravel-npm-install-buffer-name)
    (projectile-laravel-with-root
     (compile "npm install"
              'projectile-laravel-npm-install-mode))))

(defun projectile-laravel-npm-watch ()
  "Run npm watch command."
  (interactive)
  (when (not (projectile-laravel--file-exists-p ".env"))
    (user-error "You're not running it from a laravel application"))
  (if (member projectile-laravel-npm-watch-buffer-name (mapcar 'buffer-name (buffer-list)))
      (switch-to-buffer projectile-laravel-npm-watch-buffer-name)
    (projectile-laravel-with-root
     (compile "npm run watch"
              'projectile-laravel-npm-watch-mode))))

(defun projectile-laravel--completion-in-region ()
  (interactive)
  (let ((generators (--map (concat (car it) " ") projectile-laravel-generators)))
    (when (<= (minibuffer-prompt-end) (point))
      (completion-in-region (minibuffer-prompt-end) (point-max)
                            generators))))

(defun projectile-laravel--generate-with-completion (command)
  (let ((keymap (copy-keymap minibuffer-local-map)))
    (define-key keymap (kbd "<tab>") 'projectile-laravel--completion-in-region)
    (concat command (read-from-minibuffer command nil keymap))))

(defun laravel-make-model(&optional args)
  (interactive
   (list (transient-args 'projectile-laravel-generate-model)))
  (let ((options (if args (substring (format "%s" args) 1 -1) "")))
    (projectile-laravel-with-root
     (compile
      (format "php artisan make:model %s %s" options (read-from-minibuffer "Make model:"))
      'projectile-laravel-generate-mode))))

(defun laravel-make-controller(&optional args)
  (interactive
   (list (transient-args 'projectile-laravel-generate-controller)))
  (let ((options (if args (substring (format "%s" args) 1 -1) "")))
    (projectile-laravel-with-root
     (compile
      (format "php artisan make:controller %s %s" options (read-from-minibuffer "Make controller:"))
      'projectile-laravel-generate-mode))))

(defun laravel-make-migration(&optional args)
  (interactive
   (list (transient-args 'projectile-laravel-generate-migration)))
  (let ((options (if args (substring (format "%s" args) 1 -1) "")))
    (projectile-laravel-with-root
     (compile
      (format "php artisan make:migration %s %s" options (read-from-minibuffer "Make migration:"))
      'projectile-laravel-generate-mode))))

(defun laravel-make-test(&optional args)
  (interactive
   (list (transient-args 'projectile-laravel-generate-test)))
  (let ((options (if args (substring (format "%s" args) 1 -1) "")))
    (projectile-laravel-with-root
     (compile
      (format "php artisan make:test %s %s" options (read-from-minibuffer "Make test:"))
      'projectile-laravel-generate-mode))))

(defun laravel-make-component(&optional args)
  (interactive
   (list (transient-args 'projectile-laravel-generate-component)))
  (let ((options (if args (substring (format "%s" args) 1 -1) "")))
    (projectile-laravel-with-root
     (compile
      (format "php artisan make:component %s %s" options (read-from-minibuffer "Make component:"))
      'projectile-laravel-generate-mode))))

(defun laravel-make-resource(&optional args)
  (interactive
   (list (transient-args 'projectile-laravel-generate-resource)))
  (let ((options (if args (substring (format "%s" args) 1 -1) "")))
    (projectile-laravel-with-root
     (compile
      (format "php artisan make:resource %s %s" options (read-from-minibuffer "Make resource:"))
      'projectile-laravel-generate-mode))))

(defun laravel-make-livewire(&optional args)
  (interactive
   (list (transient-args 'projectile-laravel-generate-livewire)))
  (let ((options (if args (substring (format "%s" args) 1 -1) "")))
    (projectile-laravel-with-root
     (compile
      (format "php artisan make:livewire %s %s" options (read-from-minibuffer "Make livewire:"))
      'projectile-laravel-generate-mode))))

(defun laravel-make-factory(&optional args)
  (interactive
   (list (transient-args 'projectile-laravel-generate-factory)))
  (let ((options (if args (substring (format "%s" args) 1 -1) "")))
    (projectile-laravel-with-root
     (compile
      (format "php artisan make:factory %s %s" options (read-from-minibuffer "Make factory:"))
      'projectile-laravel-generate-mode))))

(defun laravel-make-command(&optional args)
  (interactive
   (list (transient-args 'projectile-laravel-generate-command)))
  (let ((options (if args (substring (format "%s" args) 1 -1) "")))
    (projectile-laravel-with-root
     (compile
      (format "php artisan make:command %s %s" options (read-from-minibuffer "Make command:"))
      'projectile-laravel-generate-mode))))

(transient-define-prefix projectile-laravel-generate-model ()
  "Transient for creating model."
  ["Options"
   ("A" "All" "--all")
   ("c" "Controller" "--controller")
   ("a" "Api" "--api")
   ("r" "Resource" "--resource")
   ("f" "Factory" "--factory")
   ("s" "Seed" "--seed")
   ]
  ["Actions"
   ("m" "Make Model" laravel-make-model)])

(transient-define-prefix projectile-laravel-generate-migration ()
  "Transient for creating migration."
  ["Options"
   ("c" "Table to be created" "--create=")
   ("t" "Table to migrate" "--table=")
   ("p" "path file should be created" "--path=")
   ("r" "Real path" "--realpath")
   ("f" "Full path" "--fullpath")
   ]
  ["Actions"
   ("m" "Make Migration" laravel-make-migration )])

(transient-define-prefix projectile-laravel-generate-controller ()
  "Transient for creating controller."
  ["Options"
   ("a" "Api" "--api")
   ("i" "Api" "--invokable")
   ("M" "Model name" "--model=")
   ("p" "Generate a nested resource controller" "--parent=")
   ("r" "resource" "--resource")
   ]
  ["Actions"
   ("m" "Make Controller" laravel-make-controller )])

(transient-define-prefix projectile-laravel-generate-test ()
  "Transient for creating test."
  ;; ["Description"
  ;;  ("Create a new test class" "" "")]
  ["Options"
   ("u" "Create a unit test" "--unit")
   ]
  ["Actions"
   ("m" "Create a new test class" laravel-make-test )])

(transient-define-prefix projectile-laravel-generate-livewire ()
  "Transient for creating livewire."
  ["Options"
   ("f" "Force" "--force")
   ("i" "Inline" "--inline")
   ("s" "[default: \"default\"]" "--stub=")
   ]
  ["Actions"
   ("m" "Create a new Livewire component" laravel-make-livewire )])

(transient-define-prefix projectile-laravel-generate-component ()
  "Transient for creating component."
  ["Options"
   ("f" "Force" "--force")
   ("i" "Inline" "--inline")
   ]
  ["Actions"
   ("m" "Create a new view component class" laravel-make-component )])

(transient-define-prefix projectile-laravel-generate-resource ()
  "Transient for creating resource."
  ["Options"
   ("c" "Create a resource collection" "--collection")
   ]
  ["Actions"
   ("m" "Create a new resource" laravel-make-resource )])

(transient-define-prefix projectile-laravel-generate-command ()
  "Transient for creating command."
  ["Options"
   ("c" "The terminal command that should be assigned [default: \"command:name\"]" "--command=")
   ]
  ["Actions"
   ("m" "Create a new Artisan command" laravel-make-command )])

(transient-define-prefix projectile-laravel-generate-factory ()
  "Transient for creating factory."
  ["Options"
   ("M" "The name of the model" "--model=")
   ]
  ["Actions"
   ("m" " Create a new model factory" laravel-make-factory )])

(transient-define-prefix projectile-laravel-migrate ()
  "Transient for database migration."
  ["Migrate"
   ("f" "Fresh" "Drop all tables and re-run all migrations" laravel-migrate-fresh)
   ("i" "Install" "Create the migration repository" laravel-migrate-install)
   ("r" "Refresh" "Reset and re-run all migrations" laravel-migrate-refresh)
   ("r" "Reset" "Rollback all database migrations" laravel-migrate-reset)
   ("b" "Rollback" "Rollback the last database migration" laravel-migrate-rollback)
   ("s" "Status" "Show the status of each migration" laravel-migrate-status)
   ])

(defun laravel-migrate-fresh ()
  (projectile-laravel-with-root
   (compile "php artisan migration:fresh"
            'projectile-laravel-generate-mode)))

(defun laravel-migrate-install ()
  (projectile-laravel-with-root
   (compile "php artisan migration:install"
            'projectile-laravel-generate-mode)))

(defun laravel-migrate-refresh ()
  (projectile-laravel-with-root
   (compile "php artisan migration:refresh"
            'projectile-laravel-generate-mode)))

(defun laravel-migrate-reset ()
  (projectile-laravel-with-root
   (compile "php artisan migration:reset"
            'projectile-laravel-generate-mode)))

(defun laravel-migrate-rollback ()
  (projectile-laravel-with-root
   (compile "php artisan migration:rollback"
            'projectile-laravel-generate-mode)))

(defun laravel-migrate-status ()
  (projectile-laravel-with-root
   (compile "php artisan migration:status"
            'projectile-laravel-generate-mode)))

(defun projectile-laravel-generate-rule ()
  (projectile-laravel-with-root
   (compile
    (format "php artisan make:rule %s" (read-from-minibuffer "Make rule:"))
    'projectile-laravel-generate-mode)))

(defun projectile-laravel-generate-middleware ()
  (projectile-laravel-with-root
   (compile
    (format "php artisan make:middleware %s" (read-from-minibuffer "Make middleware:"))
    'projectile-laravel-generate-mode)))


(defun projectile-laravel--destroy-read (command)
  (let ((keymap (copy-keymap minibuffer-local-map)))
    (define-key keymap (kbd "<tab>") 'exit-minibuffer)
    (read-from-minibuffer command nil keymap)))

(defun projectile-laravel--destroy-with-completion (command)
  (let* ((user-input (projectile-laravel--destroy-read command))
         (completion (try-completion user-input
                                     projectile-laravel-generators))
         (dirs (cdr (-flatten-n 2 (--filter (string= completion (car it))
                                            projectile-laravel-generators))))
         (prompt (concat command completion " ")))
    (if completion
        (concat prompt
                (projectile-completing-read
                 prompt
                 (projectile-laravel-hash-keys (projectile-laravel-choices dirs))))
      (concat command user-input))))

;;TODO delete server and npm stuff or call this terminate ?
(defun projectile-laravel-destroy ()
  "Run laravel destroy command."
  (interactive)
  (projectile-laravel-with-root
   (compile
    (projectile-laravel--destroy-with-completion projectile-laravel-custom-destroy-command)
    'projectile-laravel-compilation-mode)))

(defun projectile-laravel-sanitize-and-goto-file (dir name &optional ext)
  "Sanitize DIR, NAME and EXT then passe them to `projectile-laravel-goto-file'."
  (projectile-laravel-goto-file
   (concat
    (projectile-laravel-sanitize-dir-name dir) (projectile-laravel-declassify name) ext)))

(defun projectile-laravel-goto-file (filepath &optional ask)
  "Find FILEPATH after expanding root.  ASK is passed straight to `projectile-laravel-ff'."
  (projectile-laravel-ff (projectile-laravel-expand-root filepath) ask))

(defun projectile-laravel-goto-asset-at-point (dirs)
  "Try to find and go to an asset under the point.

DIRS are directories where to look for assets."
  (let ((name
         (projectile-laravel-sanitize-name (thing-at-point 'filename))))
    (projectile-laravel-ff
     (cl-loop for dir in dirs
              for re = (s-lex-format "${name}\\(\\..+\\)*$")
              for files = (projectile-dir-files (projectile-laravel-expand-root dir))
              for file = (--first (string-match-p re it) files)
              until file
              finally return (and file (projectile-laravel-expand-root (concat dir file)))))))

(defun projectile-laravel-goto-constant-at-point ()
  "Try to find and go to a Ruby constant at point."
  (let ((bounds (projectile-laravel--complete-bounds)))
    (projectile-laravel-find-constant (buffer-substring (car bounds) (cdr bounds)))))

;; Stolen from robe
(defun projectile-laravel--complete-bounds ()
  (cons
   (save-excursion
     (while (or (not (zerop (skip-syntax-backward "w_")))
                (not (zerop (skip-chars-backward ":")))))
     (point))
   (save-excursion
     (while (or (not (zerop (skip-syntax-forward "w_")))
                (not (zerop (skip-chars-forward ":")))))
     (point))))

(defun projectile-laravel-find-constant (name)
  (let* ((code-dirs (-filter #'f-exists? (-map #'projectile-laravel-expand-root (projectile-laravel--code-directories))))
         (list-parent-dirs (lambda (some-file)
                             (let ((parent-dirs '()))
                               (f-traverse-upwards (lambda (parent-dir)
                                                     (push (f-canonical parent-dir) parent-dirs)
                                                     (equal (f-slash (f-canonical (projectile-laravel-root))) (f-slash (f-canonical parent-dir))))
                                                   (f-dirname some-file))
                               parent-dirs)))
         (file-name (format "%s.php" (projectile-laravel-declassify name)))
         (lookup-dirs (if (f-absolute? file-name)
                          ;; If top-level constant (e.g. ::Classname), i.e. derived filename (/classname) starts with a "/", then:
                          ;; Look only in code directories
                          code-dirs
                        (-flatten (list
                                   ;; Otherwise (relative constant):
                                   ;; 1. Look in current file namespace
                                   (f-no-ext buffer-file-name)
                                   ;; 2. Look in local namespace hierarchy
                                   (funcall list-parent-dirs buffer-file-name)
                                   ;; 3. Look in code directories
                                   code-dirs))))
         ;; Strip leading "/" if present before generating lookup paths because it messes with f-join)
         (relative-file-name (if (f-absolute? file-name)
                                 (substring file-name 1)
                               file-name))
         (lookup-paths (--map (f-join it relative-file-name)
                              lookup-dirs))
         (choices
          (-uniq
           (-filter #'f-exists? lookup-paths))))

    (when (= (length choices) 0)
      (user-error "Could not find anything"))

    (cond ((= (length choices) 1)
           (find-file (car choices)))
          ((> (length choices) 1)
           (find-file (projectile-completing-read "Which exactly?: " choices))))))

(defun projectile-laravel--code-directories ()
  (let ((app-dirs (projectile-laravel-list-entries 'f-directories "app/")))
    (-concat
     (--map (concat "app/" it "/") app-dirs)
     (--map (concat "app/" it "/concerns/") app-dirs)
     '("lib/"))))

(defun projectile-laravel--view-p (path)
  (string-prefix-p "resources/views/" (s-chop-prefix (projectile-laravel-root) path)))

(defun projectile-laravel--ignore-buffer-p ()
  "Return t if `projectile-laravel' should not be enabled for the current buffer."
  (string-match-p "\\*\\(Minibuf-[0-9]+\\|helm mini\\|helm projectile\\)\\*" (buffer-name)))

(defun projectile-laravel-template-name (template)
  (-first-item (s-split "\\." (-last-item (s-split "/" template)))))

(defun projectile-laravel-template-format (template)
  (let ((at-point-re "\\.\\([^.]+\\)\\.[^.]+$")
        (at-line-re "formats\\(?:'\"\\|:\\)?\\s-*\\(?:=>\\)?\\s-*\\[[:'\"]\\([a-zA-Z0-9]+\\)['\"]?\\]"))
    (cond ((string-match at-point-re template)
           (match-string 1 template))
          ((string-match at-line-re (projectile-laravel-current-line))
           (match-string 1 (projectile-laravel-current-line)))
          (t
           (when (string-match at-point-re (buffer-file-name))
             (match-string 1 (buffer-file-name)))))))

(defun projectile-laravel-template-dir (template)
  (projectile-laravel-sanitize-dir-name
   (cond ((string-match "\\(.+\\)/[^/]+$" template)
          (projectile-laravel-expand-root
           (concat "resources/views/" (match-string 1 template))))
         ((string-match "app/Http/Controllers/\\(.+\\)Controller\\.php$" (buffer-file-name))
          (projectile-laravel-expand-root
           (concat "resources/views/" (match-string 1 (buffer-file-name)))))
         (t
          default-directory))))

(defun projectile-laravel--goto-template-at-point (dir name format)
  (cl-loop for processor in '("erb" "haml" "slim")
           for template = (s-lex-format "${dir}${name}.${format}.${processor}")
           for partial = (s-lex-format "${dir}_${name}.${format}.${processor}")
           until (or
                  (projectile-laravel-ff template)
                  (projectile-laravel-ff partial))))

(defun projectile-laravel-goto-template-at-point ()
  "Visit a template or a partial under the point."
  (interactive)
  (let* ((template (projectile-laravel-filename-at-point))
         (dir (projectile-laravel-template-dir template))
         (name (projectile-laravel-template-name template))
         (format (projectile-laravel-template-format template)))
    (if format
        (or (projectile-laravel--goto-template-at-point dir name format)
            (projectile-laravel--goto-template-at-point (projectile-laravel-expand-root "resources/views/")
                                                        name
                                                        format))
      (message "Could not recognize the template's format")
      (dired dir))))

(defun projectile-laravel-goto-composer ()
  "Visit composer.json file."
  (interactive)
  (projectile-laravel-goto-file "composer.json"))

(defun projectile-laravel-goto-package ()
  "Visit package.json file."
  (interactive)
  (projectile-laravel-goto-file "package.json"))

(defun projectile-laravel-goto-env ()
  "Visit .env file."
  (interactive)
  (projectile-laravel-goto-file ".env"))

(defun projectile-laravel-goto-api-routes ()
  "Visit routes/api.php file."
  (interactive)
  (projectile-laravel-goto-file "routes/api.php"))

(defun projectile-laravel-goto-web-routes ()
  "Visit routes/web.php file."
  (interactive)
  (projectile-laravel-goto-file "routes/web.php"))

(defun projectile-laravel-ff (path &optional ask)
  "Call `find-file' function on PATH when it is not nil and the file exists.

If file does not exist and ASK in not nil it will ask user to proceed."
  (if (or (and path (file-exists-p path))
          (and ask (yes-or-no-p (s-lex-format "File does not exists. Create a new buffer ${path} ?"))))
      (find-file path)))

(defun projectile-laravel-name-at-point ()
  (projectile-laravel-sanitize-name (symbol-name (symbol-at-point))))

(defun projectile-laravel-filename-at-point ()
  (projectile-laravel-sanitize-name (thing-at-point 'filename)))

(defun projectile-laravel-apply-ansi-color ()
  (ansi-color-apply-on-region compilation-filter-start (point)))

(defun projectile-laravel--log-buffer-find-template (button)
  (projectile-laravel-sanitize-and-goto-file "resources/views/" (button-label button)))

(defun projectile-laravel--log-buffer-find-controller (button)
  (projectile-laravel-sanitize-and-goto-file "app/Http/Controllers/" (button-label button) ".php"))

(defun projectile-laravel--generate-buffer-make-buttons (buffer exit-code)
  (with-current-buffer buffer
    (goto-char 0)
    (while (re-search-forward projectile-laravel-generate-filepath-re (max-char) t)
      (make-button
       (match-beginning 1)
       (match-end 1)
       'action
       'projectile-laravel-generate-ff
       'follow-link
       t))))

(defun projectile-laravel-server-make-buttons ()
  (projectile-laravel--log-buffer-make-buttons compilation-filter-start (point)))

(defun projectile-laravel--log-buffer-make-buttons (start end)
  (save-excursion
    (goto-char start)
    (while (not (= (point) end))
      (cond ((re-search-forward "Rendered \\([^ ]+\\)" (line-end-position) t)
             (make-button (match-beginning 1) (match-end 1) 'action 'projectile-laravel--log-buffer-find-template 'follow-link t))
            ((re-search-forward "Processing by \\(.+\\)#\\(?:[^ ]+\\)" (line-end-position) t)
             (make-button (match-beginning 1) (match-end 1) 'action 'projectile-laravel--log-buffer-find-controller 'follow-link t)))
      (forward-line))))

(defun projectile-laravel-server-terminate ()
  (let ((process (get-buffer-process projectile-laravel-server-buffer-name)))
    (when process (signal-process process 15))))

(defun projectile-laravel-npm-watch-terminate ()
  (let ((process (get-buffer-process projectile-laravel-npm-watch-buffer-name)))
    (when process (signal-process process 15))))

(defun projectile-laravel-generate-ff (button)
  (find-file (projectile-laravel-expand-root (button-label button))))

(defun projectile-laravel-sanitize-name (name)
  (when (or
         (and (s-starts-with? "'" name) (s-ends-with? "'" name))
         (and (s-starts-with? "\"" name) (s-ends-with? "\"" name)))
    (setq name (substring name 1 -1)))
  (when (s-starts-with? "./" name)
    (setq name (substring name 2)))
  (when (or (string-match-p "^:[^:]" name) (s-starts-with? "/" name))
    (setq name (substring name 1)))
  (when (s-ends-with? "," name)
    (setq name (substring name 0 -1)))
  name)

(defun projectile-laravel-sanitize-dir-name (name)
  (projectile-laravel--ensure-suffix name "/"))

(defun projectile-laravel--ensure-suffix (name suffix)
  (if (s-ends-with? suffix name) name (concat name suffix)))

(defun projectile-laravel-current-line ()
  (save-excursion
    (let (beg)
      (beginning-of-line)
      (setq beg (point))
      (end-of-line)
      (buffer-substring-no-properties beg (point)))))

(defun projectile-laravel-set-assets-dirs ()
  (setq-local
   projectile-laravel-javascript-dirs
   (--filter (projectile-laravel--file-exists-p it) projectile-laravel-javascript-dirs))
  (setq-local
   projectile-laravel-stylesheet-dirs
   (--filter (projectile-laravel--file-exists-p it) projectile-laravel-stylesheet-dirs)))

;;;###autoload
(define-minor-mode projectile-laravel-mode
  "Laravel mode based on projectile"
  :init-value nil
  :lighter " Laravel"
  (when projectile-laravel-mode
    (and projectile-laravel-add-keywords (projectile-laravel-add-keywords-for-file-type))
    (projectile-laravel-set-assets-dirs)))

;;;###autoload
(defun projectile-laravel-on ()
  "Enable `projectile-laravel-mode' minor mode if this is a laravel project."
  (when (and
         (not (projectile-laravel--ignore-buffer-p))
         (projectile-project-p)
         (projectile-laravel-root))
    (projectile-laravel-mode +1)))

;;;###autoload
(define-globalized-minor-mode projectile-laravel-global-mode
  projectile-laravel-mode
  projectile-laravel-on)

(defun projectile-laravel-off ()
  "Disable `projectile-laravel-mode' minor mode."
  (projectile-laravel-mode -1))

(defun projectile-laravel-server-compilation-filter ()
  (projectile-laravel-server-make-buttons)
  (when projectile-laravel-server-mode-ansi-colors
    (projectile-laravel-apply-ansi-color)))

(define-derived-mode projectile-laravel-server-mode compilation-mode "Projectile Laravel Server"
  "Compilation mode for running laravel server used by `projectile-laravel'.

Killing the buffer will terminate to server's process."
  (set (make-local-variable 'compilation-error-regexp-alist) (list 'ruby-Test::Unit))
  (add-hook 'compilation-filter-hook 'projectile-laravel-server-compilation-filter)
  (add-hook 'kill-buffer-hook 'projectile-laravel-server-terminate t t)
  (add-hook 'kill-emacs-hook 'projectile-laravel-server-terminate t t)
  (setq-local compilation-scroll-output t)
  (projectile-laravel-mode +1)
  (read-only-mode -1))

(define-derived-mode projectile-laravel-composer-install-mode compilation-mode "Projectile composer install"
  "Compilation mode for running composer install used by `projectile-laravel'.

Killing the buffer will terminate to server's process."
  ;; (set (make-local-variable 'compilation-error-regexp-alist) (list 'ruby-Test::Unit))
  (add-hook 'compilation-filter-hook 'projectile-laravel-server-compilation-filter)
  (add-hook 'kill-buffer-hook 'projectile-laravel-composer-install-terminate t t)
  (add-hook 'kill-emacs-hook 'projectile-laravel-composer-install-terminate t t)
  (setq-local compilation-scroll-output t)
  (projectile-laravel-mode +1)
  (read-only-mode -1))

(define-derived-mode projectile-laravel-npm-install-mode compilation-mode "Projectile npm install"
  "Compilation mode for running npm install used by `projectile-laravel'.

Killing the buffer will terminate to server's process."
  ;; (set (make-local-variable 'compilation-error-regexp-alist) (list 'ruby-Test::Unit))
  (add-hook 'compilation-filter-hook 'projectile-laravel-server-compilation-filter)
  (add-hook 'kill-buffer-hook 'projectile-laravel-npm-install-terminate t t)
  (add-hook 'kill-emacs-hook 'projectile-laravelnpm-install-terminate t t)
  (setq-local compilation-scroll-output t)
  (projectile-laravel-mode +1)
  (read-only-mode -1))

(define-derived-mode projectile-laravel-npm-watch-mode compilation-mode "Projectile npm watch"
  "Compilation mode for running npm watch used by `projectile-laravel'.

Killing the buffer will terminate to server's process."
  ;; (set (make-local-variable 'compilation-error-regexp-alist) (list 'ruby-Test::Unit))
  (add-hook 'compilation-filter-hook 'projectile-laravel-server-compilation-filter)
  (add-hook 'kill-buffer-hook 'projectile-laravel-npm-watch-terminate t t)
  (add-hook 'kill-emacs-hook 'projectile-laravel-npm-watch-terminate t t)
  (setq-local compilation-scroll-output t)
  (projectile-laravel-mode +1)
  (read-only-mode -1))

(define-derived-mode projectile-laravel-compilation-mode compilation-mode "Projectile Laravel Compilation"
  "Compilation mode used by `projectile-laravel'."
  (add-hook 'compilation-filter-hook 'projectile-laravel-apply-ansi-color nil t)
  (projectile-laravel-mode +1))

(define-derived-mode projectile-laravel-generate-mode projectile-laravel-compilation-mode "Projectile Laravel Generate"
  "Mode for output of laravel generate."
  (add-hook 'compilation-finish-functions 'projectile-laravel--generate-buffer-make-buttons nil t)
  (projectile-laravel-mode +1))

(with-no-warnings
  (ignore-errors
    (defhydra hydra-projectile-laravel-find (:color blue :columns 8)
      "Find a resources"
      ("m" projectile-laravel-find-model       "model")
      ("v" projectile-laravel-find-view        "view")
      ("c" projectile-laravel-find-controller  "controller")
      ;; ("h" projectile-laravel-find-helper      "helper")
      ("j" projectile-laravel-find-javascript  "javascript")
      ("a" projectile-laravel-find-middleware  "middleware")
      ("r" projectile-laravel-find-resource    "resource")
      ("s" projectile-laravel-find-seeder      "seeder")
      ("f" projectile-laravel-find-factory      "factory")
      ("g" projectile-laravel-find-config      "config")
      ;; ("f" projectile-laravel-find-public-storage      "public storage")
      ("w" projectile-laravel-find-component   "component")
      ;; ("s" projectile-laravel-find-stylesheet  "stylesheet")
      ;; ("u" projectile-laravel-find-fixture     "fixture")
      ("t" projectile-laravel-find-test        "test")
      ("o" projectile-laravel-find-log         "log")
      ;; ("@" projectile-laravel-find-mailer      "mailer")
      ("y" projectile-laravel-find-layout      "layout")
      ("n" projectile-laravel-find-migration   "migration")
      ("b" projectile-laravel-find-job         "job")
      ("p" projectile-laravel-find-provider    "provider")

      ("M" projectile-laravel-find-current-model      "current model")
      ("V" projectile-laravel-find-current-view       "current view")
      ("C" projectile-laravel-find-current-controller "current controller")
      ("S" projectile-laravel-find-current-seeder     "current seeder")
      ("F" projectile-laravel-find-current-factory    "current factory")
      ;; ("H" projectile-laravel-find-current-helper     "current helper")
      ;; ("J" projectile-laravel-find-current-javascript "current javascript")
      ;; ("S" projectile-laravel-find-current-stylesheet "current stylesheet")
      ("T" projectile-laravel-find-current-test       "current test")
      ("N" projectile-laravel-find-current-migration  "current migration"))

    (defhydra hydra-projectile-laravel-goto (:color blue :columns 8)
      "Go to"
      ("f" projectile-laravel-goto-file-at-point "file at point")
      ("c" projectile-laravel-goto-composer      "composer")
      ("p" projectile-laravel-goto-package       "package")
      ("w" projectile-laravel-goto-web-routes     "web route")
      ("a" projectile-laravel-goto-api-routes     "api route")
      ("e" projectile-laravel-goto-env           "env"))

    (defhydra hydra-projectile-laravel-run (:color blue :columns 8)
      "Run external command & interact"
      ("a" projectile-laravel-artisan    "artisan")
      ("b" projectile-laravel-dbconsole  "dbconsole")
      ("s" projectile-laravel-server     "server")
      ("i" projectile-laravel-composer-install     "composer install")
      ("I" projectile-laravel-npm-install     "npm install")
      ("w" projectile-laravel-npm-watch          "npm watch")
      ("g" hydra-projectile-laravel-generate/body   "generate")
      ("m" projectile-laravel-migrate "migrate")
      ("d" projectile-laravel-destroy    "destroy"))

    (defhydra hydra-projectile-laravel-generate (:color blue :columns 8)
      "Projectile Laravel"
      ("m" projectile-laravel-generate-model      "model")
      ("n" projectile-laravel-generate-migration  "migration")
      ("c" projectile-laravel-generate-controller "controller")
      ("t" projectile-laravel-generate-command    "Command")
      ("C" projectile-laravel-generate-component  "Component")
      ("M" projectile-laravel-generate-middleware "middleware")
      ("l" projectile-laravel-generate-livewire   "livewire")
      ("f" projectile-laravel-generate-factory    "factory")
      ("t" projectile-laravel-generate-test       "test")
      ("R" projectile-laravel-generate-rule       "rule")
      ("r" projectile-laravel-generate-resource   "resource"))

    ;;TODO livewire ?

    (defhydra hydra-projectile-laravel (:color blue :columns 8)
      "Projectile Laravel"
      ("f" hydra-projectile-laravel-find/body "Find a resource")
      ("g" hydra-projectile-laravel-goto/body "Goto")
      ("j" hydra-projectile-laravel-generate/body "Generate")
      ("r" hydra-projectile-laravel-run/body "Run & interact"))))


(defvar projectile-laravel-find-map
  (let ((map (make-sparse-keymap)))
    ;;TODO
    (define-key map (kbd "m") 'projectile-laravel-find-model)
    (define-key map (kbd "m") 'projectile-laravel-find-model)
    (define-key map (kbd "v") 'projectile-laravel-find-view)
    (define-key map (kbd "c") 'projectile-laravel-find-controller)
    (define-key map (kbd "j") 'projectile-laravel-find-javascript)
    (define-key map (kbd "a") 'projectile-laravel-find-middleware)
    (define-key map (kbd "r") 'projectile-laravel-find-resource)
    (define-key map (kbd "s") 'projectile-laravel-find-seeder)
    (define-key map (kbd "f") 'projectile-laravel-find-factory)
    (define-key map (kbd "g") 'projectile-laravel-find-config)
    (define-key map (kbd "w") 'projectile-laravel-find-component)
    (define-key map (kbd "t") 'projectile-laravel-find-test)
    (define-key map (kbd "o") 'projectile-laravel-find-log)
    (define-key map (kbd "y") 'projectile-laravel-find-layout)
    (define-key map (kbd "n") 'projectile-laravel-find-migration)
    (define-key map (kbd "b") 'projectile-laravel-find-job)
    (define-key map (kbd "p") 'projectile-laravel-find-provider)
    (define-key map (kbd "M") 'projectile-laravel-find-current-model)
    (define-key map (kbd "V") 'projectile-laravel-find-current-view)
    (define-key map (kbd "C") 'projectile-laravel-find-current-controller)
    (define-key map (kbd "S") 'projectile-laravel-find-current-seeder)
    (define-key map (kbd "F") 'projectile-laravel-find-current-factory)
    (define-key map (kbd "T") 'projectile-laravel-find-current-test)
    (define-key map (kbd "N") 'projectile-laravel-find-current-migration)
    map)
  "Keymap after `projectile-laravel-keymap-prefix'.")

(fset 'projectile-laravel-find-map projectile-laravel-find-map)

(defvar projectile-laravel-mode-goto-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "f") 'projectile-laravel-goto-file-at-point)
    (define-key map (kbd "c") 'projectile-laravel-goto-composer)
    (define-key map (kbd "p") 'projectile-laravel-goto-pacakge)
    (define-key map (kbd "w") 'projectile-laravel-goto-web-routes)
    (define-key map (kbd "a") 'projectile-laravel-goto-api-routes)
    (define-key map (kbd "e") 'projectile-laravel-goto-env)
    map)
  "A goto map for `projectile-laravel-mode'.")
(fset 'projectile-laravel-mode-goto-map projectile-laravel-mode-goto-map)

(defvar projectile-laravel-mode-run-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "a") 'projectile-laravel-artisan)
    (define-key map (kbd "b") 'projectile-laravel-dbconsole)
    (define-key map (kbd "s") 'projectile-laravel-server)
    (define-key map (kbd "i") 'projectile-laravel-composer-install)
    (define-key map (kbd "I") 'projectile-laravel-npm-install)
    (define-key map (kbd "w") 'projectile-laravel-npm-watch)
    (define-key map (kbd "g") 'projectile-laravel-generate)
    (define-key map (kbd "m") 'projectile-laravel-migrate)
    (define-key map (kbd "d") 'projectile-laravel-destroy)
    map)
  "A run map for `projectile-laravel-mode'.")
(fset 'projectile-laravel-mode-run-map projectile-laravel-mode-run-map)

(defvar projectile-laravel-generate-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "m") 'projectile-laravel-generate-model)
    (define-key map (kbd "n") 'projectile-laravel-generate-migration)
    (define-key map (kbd "c") 'projectile-laravel-generate-controller)
    (define-key map (kbd "t") 'projectile-laravel-generate-command)
    (define-key map (kbd "C") 'projectile-laravel-generate-component)
    (define-key map (kbd "M") 'projectile-laravel-generate-middleware)
    (define-key map (kbd "l") 'projectile-laravel-generate-livewire)
    (define-key map (kbd "f") 'projectile-laravel-generate-factory)
    (define-key map (kbd "t") 'projectile-laravel-generate-test)
    (define-key map (kbd "R") 'projectile-laravel-generate-rule)
    (define-key map (kbd "r") 'projectile-laravel-generate-resource)
    map)
  "A run map for `projectile-laravel-mode'.")
(fset 'projectile-laravel-generate-mode-map projectile-laravel-generate-mode-map)

(defvar projectile-laravel-command-map
  (let ((map (make-sparse-keymap)))
    ;;TODO
    (define-key map (kbd "f") 'projectile-laravel-find-map)
    (define-key map (kbd "g") 'projectile-laravel-mode-goto-map)
    (define-key map (kbd "j") 'projectile-laravel-generate-mode-map)
    (define-key map (kbd "r") 'projectile-laravel-mode-run-map)
    map)
  "Keymap after `projectile-laravel-keymap-prefix'.")

(fset 'projectile-laravel-command-map projectile-laravel-command-map)

(defvar projectile-laravel-mode-map
  (let ((map (make-sparse-keymap)))
    (when projectile-laravel-keymap-prefix
      (define-key map projectile-laravel-keymap-prefix 'projectile-laravel-command-map))
    map)
  "Keymap for `projectile-laravel-mode'.")


(provide 'projectile-laravel)

;;; projectile-laravel.el ends here


;; (format "php artisan make:model %s %s" (car (last args)) (substring (format "%s" (butlast args 1)) 1 -1))

;; (define-infix-argument laravel-make-model:--name()
;;   :description "Name(required)"
;;   :class 'transient-option
;;   :shortarg "n"
;;   :prompt "Model Name: "
;;   :argument "")


;; (defun make-model(&optional args)
;;   (interactive
;;    (list (transient-args 'laravel-make-model)))
;;   (message "args %s" args)
;;   (projectile-laravel-with-root
;;    (compile
;;     (projectile-laravel--generate-with-completion cmd)
;;     (message (format "php artisan mae:%s" args))
;;     ;;(concat "php artisan mae:" (read-from-minibuffer (concat "Make " cmd ":")) args)
;; ;;    'projectile-laravel-generate-mode))
;;  )

;;TODO
;; (defun projectile-laravel-generate (cmd)
;;   "Run laravel generate command."
;;   (interactive)
;;   (laravel-make-model))
