;; Define constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-invalid-amount (err u102))
(define-constant err-task-exists (err u103))
(define-constant err-task-closed (err u104))
(define-constant err-invalid-submission (err u105))

;; Define data vars
(define-data-var token-name (string-ascii 32) "SCIENCE")
(define-data-var token-symbol (string-ascii 10) "SCI")
(define-data-var token-uri (optional (string-utf8 256)) none)
(define-data-var total-supply uint u0)

;; Define data maps
(define-map tasks
    { task-id: uint }
    {
        title: (string-utf8 100),
        description: (string-utf8 500),
        reward: uint,
        deadline: uint,
        status: (string-ascii 10),
        owner: principal,
        required-observations: uint,
        current-observations: uint,
    }
)

(define-map submissions
    {
        task-id: uint,
        user: principal,
    }
    {
        data: (string-utf8 1000),
        timestamp: uint,
        status: (string-ascii 10),
        verified: bool,
    }
)

(define-map balances
    { owner: principal }
    { balance: uint }
)

;; SIP-010 transfer function
(define-public (transfer
        (amount uint)
        (sender principal)
        (recipient principal)
    )
    (let (
            (sender-balance (default-to u0 (get balance (map-get? balances { owner: sender }))))
            (recipient-balance (default-to u0 (get balance (map-get? balances { owner: recipient }))))
        )
        (asserts! (>= sender-balance amount) err-invalid-amount)
        (map-set balances { owner: sender } { balance: (- sender-balance amount) })
        (map-set balances { owner: recipient } { balance: (+ recipient-balance amount) })
        (ok true)
    )
)

;; Create new task
(define-public (create-task
        (title (string-utf8 100))
        (description (string-utf8 500))
        (reward uint)
        (deadline uint)
        (required-observations uint)
    )
    (let ((task-id (+ u1 (var-get total-supply))))
        (asserts! (> reward u0) err-invalid-amount)
        (asserts! (> deadline burn-block-height) err-invalid-amount)
        (map-set tasks { task-id: task-id } {
            title: title,
            description: description,
            reward: reward,
            deadline: deadline,
            status: "ACTIVE",
            owner: tx-sender,
            required-observations: required-observations,
            current-observations: u0,
        })
        (var-set total-supply task-id)
        (ok task-id)
    )
)

;; Submit observation
(define-public (submit-observation
        (task-id uint)
        (data (string-utf8 1000))
    )
    (let (
            (task (unwrap! (map-get? tasks { task-id: task-id }) err-not-found))
            (current-block burn-block-height)
        )
        (asserts! (is-eq (get status task) "ACTIVE") err-task-closed)
        (asserts! (<= current-block (get deadline task)) err-task-closed)
        (map-set submissions {
            task-id: task-id,
            user: tx-sender,
        } {
            data: data,
            timestamp: current-block,
            status: "PENDING",
            verified: false,
        })
        (map-set tasks { task-id: task-id }
            (merge task { current-observations: (+ u1 (get current-observations task)) })
        )
        (ok true)
    )
)

;; Verify submission and reward
(define-public (verify-submission
        (task-id uint)
        (user principal)
    )
    (let (
            (submission (unwrap!
                (map-get? submissions {
                    task-id: task-id,
                    user: user,
                })
                err-not-found
            ))
            (task (unwrap! (map-get? tasks { task-id: task-id }) err-not-found))
        )
        (asserts! (is-eq tx-sender (get owner task)) err-owner-only)
        (asserts! (not (get verified submission)) err-invalid-submission)
        (try! (transfer (get reward task) contract-owner user))
        (map-set submissions {
            task-id: task-id,
            user: user,
        }
            (merge submission {
                status: "VERIFIED",
                verified: true,
            })
        )
        (ok true)
    )
)

;; Read-only functions
(define-read-only (get-task (task-id uint))
    (map-get? tasks { task-id: task-id })
)

(define-read-only (get-submission
        (task-id uint)
        (user principal)
    )
    (map-get? submissions {
        task-id: task-id,
        user: user,
    })
)

(define-read-only (get-balance (user principal))
    (default-to u0 (get balance (map-get? balances { owner: user })))
)
