;; Define constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-invalid-amount (err u102))
(define-constant err-task-exists (err u103))
(define-constant err-task-closed (err u104))
(define-constant err-invalid-submission (err u105))
(define-constant err-task-completed (err u106))
(define-constant err-insufficient-reputation (err u107))
(define-constant err-invalid-category (err u108))
(define-constant err-category-exists (err u109))
(define-constant err-category-inactive (err u110))
(define-constant err-invalid-rating (err u111))
(define-constant err-feedback-exists (err u112))
(define-constant err-already-following (err u113))
(define-constant err-not-following (err u114))

;; Category constants
(define-constant category-biology "BIOLOGY")
(define-constant category-environmental "ENVIRONMENTAL")
(define-constant category-astronomy "ASTRONOMY")
(define-constant category-meteorology "METEOROLOGY")
(define-constant category-geology "GEOLOGY")
(define-constant category-physics "PHYSICS")
(define-constant category-chemistry "CHEMISTRY")
(define-constant category-ecology "ECOLOGY")

;; Define data vars
(define-data-var token-name (string-ascii 32) "SCIENCE")
(define-data-var token-symbol (string-ascii 10) "SCI")
(define-data-var token-uri (optional (string-utf8 256)) none)
(define-data-var total-supply uint u0)
(define-data-var category-counter uint u8)

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
        min-reputation: uint,
        category: (string-ascii 20),
    }
)

(define-map categories
    { name: (string-ascii 20) }
    {
        active: bool,
        description: (string-utf8 200),
        created-at: uint,
    }
)

(define-map category-stats
    { category: (string-ascii 20) }
    {
        total-tasks: uint,
        active-tasks: uint,
        completed-tasks: uint,
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

(define-map reputation
    { user: principal }
    {
        score: uint,
        verified-submissions: uint,
        rejected-submissions: uint,
    }
)

(define-map feedback
    {
        task-id: uint,
        user: principal,
    }
    {
        rating: uint,
        comment: (string-utf8 200),
        created-at: uint,
    }
)

(define-map task-rating-stats
    { task-id: uint }
    {
        rating-count: uint,
        rating-total: uint,
    }
)

(define-map task-followers
    {
        task-id: uint,
        user: principal,
    }
    { followed: bool }
)

(define-map task-follower-stats
    { task-id: uint }
    { follower-count: uint }
)

(define-map user-follow-stats
    { user: principal }
    { followed-tasks: uint }
)

;; Initialize default categories
(map-set categories { name: category-biology } {
    active: true,
    description: u"Biological research and observations",
    created-at: u0,
})
(map-set categories { name: category-environmental } {
    active: true,
    description: u"Environmental monitoring and studies",
    created-at: u0,
})
(map-set categories { name: category-astronomy } {
    active: true,
    description: u"Astronomical observations and research",
    created-at: u0,
})
(map-set categories { name: category-meteorology } {
    active: true,
    description: u"Weather and climate observations",
    created-at: u0,
})
(map-set categories { name: category-geology } {
    active: true,
    description: u"Geological and earth science studies",
    created-at: u0,
})
(map-set categories { name: category-physics } {
    active: true,
    description: u"Physics experiments and observations",
    created-at: u0,
})
(map-set categories { name: category-chemistry } {
    active: true,
    description: u"Chemistry research and analysis",
    created-at: u0,
})
(map-set categories { name: category-ecology } {
    active: true,
    description: u"Ecological research and biodiversity studies",
    created-at: u0,
})

;; Category management functions
(define-public (add-category
        (name (string-ascii 20))
        (description (string-utf8 200))
    )
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-none (map-get? categories { name: name }))
            err-category-exists
        )
        (map-set categories { name: name } {
            active: true,
            description: description,
            created-at: burn-block-height,
        })
        (map-set category-stats { category: name } {
            total-tasks: u0,
            active-tasks: u0,
            completed-tasks: u0,
        })
        (var-set category-counter (+ (var-get category-counter) u1))
        (ok true)
    )
)

(define-public (toggle-category-status (name (string-ascii 20)))
    (let ((category (unwrap! (map-get? categories { name: name }) err-not-found)))
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set categories { name: name }
            (merge category { active: (not (get active category)) })
        )
        (ok true)
    )
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
        (min-reputation uint)
        (category (string-ascii 20))
    )
    (let (
            (task-id (+ u1 (var-get total-supply)))
            (category-info (unwrap! (map-get? categories { name: category })
                err-invalid-category
            ))
            (current-stats (default-to {
                total-tasks: u0,
                active-tasks: u0,
                completed-tasks: u0,
            }
                (map-get? category-stats { category: category })
            ))
        )
        (asserts! (> reward u0) err-invalid-amount)
        (asserts! (> deadline burn-block-height) err-invalid-amount)
        (asserts! (get active category-info) err-category-inactive)
        (map-set tasks { task-id: task-id } {
            title: title,
            description: description,
            reward: reward,
            deadline: deadline,
            status: "ACTIVE",
            owner: tx-sender,
            required-observations: required-observations,
            current-observations: u0,
            min-reputation: min-reputation,
            category: category,
        })
        (map-set category-stats { category: category } {
            total-tasks: (+ (get total-tasks current-stats) u1),
            active-tasks: (+ (get active-tasks current-stats) u1),
            completed-tasks: (get completed-tasks current-stats),
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
            (new-observation-count (+ u1 (get current-observations task)))
            (user-reputation (get-reputation-score tx-sender))
        )
        (asserts! (is-eq (get status task) "ACTIVE") err-task-closed)
        (asserts! (<= current-block (get deadline task)) err-task-closed)
        (asserts! (>= user-reputation (get min-reputation task))
            err-insufficient-reputation
        )
        (map-set submissions {
            task-id: task-id,
            user: tx-sender,
        } {
            data: data,
            timestamp: current-block,
            status: "PENDING",
            verified: false,
        })
        (if (>= new-observation-count (get required-observations task))
            (let ((current-stats (default-to {
                    total-tasks: u0,
                    active-tasks: u0,
                    completed-tasks: u0,
                }
                    (map-get? category-stats { category: (get category task) })
                )))
                (map-set tasks { task-id: task-id }
                    (merge task {
                        current-observations: new-observation-count,
                        status: "COMPLETED",
                    })
                )
                (map-set category-stats { category: (get category task) } {
                    total-tasks: (get total-tasks current-stats),
                    active-tasks: (- (get active-tasks current-stats) u1),
                    completed-tasks: (+ (get completed-tasks current-stats) u1),
                })
            )
            (map-set tasks { task-id: task-id }
                (merge task { current-observations: new-observation-count })
            )
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
            (current-rep (default-to {
                score: u0,
                verified-submissions: u0,
                rejected-submissions: u0,
            }
                (map-get? reputation { user: user })
            ))
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
        (map-set reputation { user: user } {
            score: (+ (get score current-rep) u10),
            verified-submissions: (+ (get verified-submissions current-rep) u1),
            rejected-submissions: (get rejected-submissions current-rep),
        })
        (ok true)
    )
)

(define-public (reject-submission
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
            (current-rep (default-to {
                score: u0,
                verified-submissions: u0,
                rejected-submissions: u0,
            }
                (map-get? reputation { user: user })
            ))
        )
        (asserts! (is-eq tx-sender (get owner task)) err-owner-only)
        (asserts! (not (get verified submission)) err-invalid-submission)
        (map-set submissions {
            task-id: task-id,
            user: user,
        }
            (merge submission {
                status: "REJECTED",
                verified: false,
            })
        )
        (map-set reputation { user: user } {
            score: (if (>= (get score current-rep) u5)
                (- (get score current-rep) u5)
                u0
            ),
            verified-submissions: (get verified-submissions current-rep),
            rejected-submissions: (+ (get rejected-submissions current-rep) u1),
        })
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

(define-read-only (is-task-completed (task-id uint))
    (match (map-get? tasks { task-id: task-id })
        task (>= (get current-observations task) (get required-observations task))
        false
    )
)

(define-read-only (get-reputation-score (user principal))
    (default-to u0 (get score (map-get? reputation { user: user })))
)

(define-read-only (get-user-reputation (user principal))
    (default-to {
        score: u0,
        verified-submissions: u0,
        rejected-submissions: u0,
    }
        (map-get? reputation { user: user })
    )
)

;; Category-related read-only functions
(define-read-only (get-category (name (string-ascii 20)))
    (map-get? categories { name: name })
)

(define-read-only (is-category-active (name (string-ascii 20)))
    (match (map-get? categories { name: name })
        category (get active category)
        false
    )
)

(define-read-only (get-category-stats (category (string-ascii 20)))
    (default-to {
        total-tasks: u0,
        active-tasks: u0,
        completed-tasks: u0,
    }
        (map-get? category-stats { category: category })
    )
)

(define-read-only (get-task-by-id-and-check-category
        (task-id uint)
        (category (string-ascii 20))
    )
    (match (map-get? tasks { task-id: task-id })
        task (if (is-eq (get category task) category)
            (some task)
            none
        )
        none
    )
)

(define-read-only (is-task-in-category
        (task-id uint)
        (category (string-ascii 20))
    )
    (match (map-get? tasks { task-id: task-id })
        task (is-eq (get category task) category)
        false
    )
)

(define-read-only (get-task-category (task-id uint))
    (match (map-get? tasks { task-id: task-id })
        task (some (get category task))
        none
    )
)

(define-read-only (count-tasks-in-category (category (string-ascii 20)))
    (get total-tasks (get-category-stats category))
)

(define-public (leave-feedback
        (task-id uint)
        (rating uint)
        (comment (string-utf8 200))
    )
    (let (
            (submission (unwrap!
                (map-get? submissions {
                    task-id: task-id,
                    user: tx-sender,
                })
                err-not-found
            ))
            (existing-feedback (map-get? feedback {
                task-id: task-id,
                user: tx-sender,
            }))
            (has-valid-min (>= rating u1))
            (has-valid-max (<= rating u5))
            (current-block burn-block-height)
            (current-stats (default-to {
                rating-count: u0,
                rating-total: u0,
            }
                (map-get? task-rating-stats { task-id: task-id })
            ))
        )
        (asserts! (and has-valid-min has-valid-max) err-invalid-rating)
        (asserts! (is-none existing-feedback) err-feedback-exists)
        (asserts! (get verified submission) err-invalid-submission)
        (map-set feedback {
            task-id: task-id,
            user: tx-sender,
        } {
            rating: rating,
            comment: comment,
            created-at: current-block,
        })
        (map-set task-rating-stats { task-id: task-id } {
            rating-count: (+ (get rating-count current-stats) u1),
            rating-total: (+ (get rating-total current-stats) rating),
        })
        (ok true)
    )
)

(define-read-only (get-feedback
        (task-id uint)
        (user principal)
    )
    (map-get? feedback {
        task-id: task-id,
        user: user,
    })
)

(define-read-only (get-task-rating-stats (task-id uint))
    (default-to {
        rating-count: u0,
        rating-total: u0,
    }
        (map-get? task-rating-stats { task-id: task-id })
    )
)

(define-read-only (get-task-average-rating (task-id uint))
    (let (
            (stats (default-to {
                rating-count: u0,
                rating-total: u0,
            }
                (map-get? task-rating-stats { task-id: task-id })
            ))
            (count (get rating-count stats))
        )
        (if (is-eq count u0)
            u0
            (/ (get rating-total stats) count)
        )
    )
)

(define-public (follow-task (task-id uint))
    (let (
            (task (map-get? tasks { task-id: task-id }))
            (existing (map-get? task-followers {
                task-id: task-id,
                user: tx-sender,
            }))
            (current-task-stats (default-to { follower-count: u0 }
                (map-get? task-follower-stats { task-id: task-id })
            ))
            (current-user-stats (default-to { followed-tasks: u0 }
                (map-get? user-follow-stats { user: tx-sender })
            ))
        )
        (asserts! (is-some task) err-not-found)
        (asserts! (is-none existing) err-already-following)
        (map-set task-followers {
            task-id: task-id,
            user: tx-sender,
        } { followed: true }
        )
        (map-set task-follower-stats { task-id: task-id } { follower-count: (+ (get follower-count current-task-stats) u1) })
        (map-set user-follow-stats { user: tx-sender } { followed-tasks: (+ (get followed-tasks current-user-stats) u1) })
        (ok true)
    )
)

(define-public (unfollow-task (task-id uint))
    (let (
            (task (map-get? tasks { task-id: task-id }))
            (existing (map-get? task-followers {
                task-id: task-id,
                user: tx-sender,
            }))
            (current-task-stats (default-to { follower-count: u0 }
                (map-get? task-follower-stats { task-id: task-id })
            ))
            (current-user-stats (default-to { followed-tasks: u0 }
                (map-get? user-follow-stats { user: tx-sender })
            ))
            (task-follower-count (get follower-count current-task-stats))
            (user-followed-count (get followed-tasks current-user-stats))
        )
        (asserts! (is-some task) err-not-found)
        (asserts! (is-some existing) err-not-following)
        (map-delete task-followers {
            task-id: task-id,
            user: tx-sender,
        })
        (map-set task-follower-stats { task-id: task-id } { follower-count: (if (> task-follower-count u0)
            (- task-follower-count u1)
            u0
        ) }
        )
        (map-set user-follow-stats { user: tx-sender } { followed-tasks: (if (> user-followed-count u0)
            (- user-followed-count u1)
            u0
        ) }
        )
        (ok true)
    )
)

(define-read-only (is-following-task
        (task-id uint)
        (user principal)
    )
    (is-some (map-get? task-followers {
        task-id: task-id,
        user: user,
    }))
)

(define-read-only (get-task-follower-stats (task-id uint))
    (default-to { follower-count: u0 }
        (map-get? task-follower-stats { task-id: task-id })
    )
)

(define-read-only (get-user-follow-stats (user principal))
    (default-to { followed-tasks: u0 }
        (map-get? user-follow-stats { user: user })
    )
)
