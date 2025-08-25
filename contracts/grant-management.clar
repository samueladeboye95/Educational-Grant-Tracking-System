;; Educational Grant Management Contract
;; Handles grant applications, approvals, and lifecycle management

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-GRANT-NOT-FOUND (err u101))
(define-constant ERR-INVALID-STATUS (err u102))
(define-constant ERR-INVALID-AMOUNT (err u103))
(define-constant ERR-INVALID-DURATION (err u104))
(define-constant ERR-ALREADY-EXISTS (err u105))
(define-constant ERR-INVALID-INPUT (err u106))

;; Grant status constants
(define-constant STATUS-SUBMITTED u1)
(define-constant STATUS-UNDER-REVIEW u2)
(define-constant STATUS-APPROVED u3)
(define-constant STATUS-REJECTED u4)
(define-constant STATUS-ACTIVE u5)
(define-constant STATUS-COMPLETED u6)
(define-constant STATUS-CANCELLED u7)

;; Data Variables
(define-data-var next-grant-id uint u1)
(define-data-var contract-admin principal CONTRACT-OWNER)

;; Data Maps
(define-map grants
  { grant-id: uint }
  {
    title: (string-ascii 200),
    description: (string-ascii 1000),
    principal-investigator: principal,
    institution: (string-ascii 100),
    department: (string-ascii 100),
    budget-amount: uint,
    duration-days: uint,
    status: uint,
    submission-date: uint,
    approval-date: (optional uint),
    reviewer: (optional principal),
    start-date: (optional uint),
    end-date: (optional uint)
  }
)

(define-map grant-investigators
  { grant-id: uint, investigator: principal }
  { role: (string-ascii 50), added-date: uint }
)

(define-map authorized-reviewers
  { reviewer: principal }
  { institution: (string-ascii 100), authorized-date: uint, active: bool }
)

(define-map institution-admins
  { admin: principal }
  { institution: (string-ascii 100), authorized-date: uint, active: bool }
)

;; Read-only functions
(define-read-only (get-grant (grant-id uint))
  (map-get? grants { grant-id: grant-id })
)

(define-read-only (get-grant-investigators (grant-id uint))
  (map-get? grant-investigators { grant-id: grant-id, investigator: tx-sender })
)

(define-read-only (is-authorized-reviewer (reviewer principal))
  (match (map-get? authorized-reviewers { reviewer: reviewer })
    reviewer-data (get active reviewer-data)
    false
  )
)

(define-read-only (is-institution-admin (admin principal))
  (match (map-get? institution-admins { admin: admin })
    admin-data (get active admin-data)
    false
  )
)

(define-read-only (get-next-grant-id)
  (var-get next-grant-id)
)

(define-read-only (get-contract-admin)
  (var-get contract-admin)
)

;; Private functions
(define-private (is-valid-status (status uint))
  (and (>= status u1) (<= status u7))
)

(define-private (can-transition-status (current-status uint) (new-status uint))
  (or
    ;; Submitted -> Under Review
    (and (is-eq current-status STATUS-SUBMITTED) (is-eq new-status STATUS-UNDER-REVIEW))
    ;; Under Review -> Approved/Rejected
    (and (is-eq current-status STATUS-UNDER-REVIEW)
         (or (is-eq new-status STATUS-APPROVED) (is-eq new-status STATUS-REJECTED)))
    ;; Approved -> Active
    (and (is-eq current-status STATUS-APPROVED) (is-eq new-status STATUS-ACTIVE))
    ;; Active -> Completed/Cancelled
    (and (is-eq current-status STATUS-ACTIVE)
         (or (is-eq new-status STATUS-COMPLETED) (is-eq new-status STATUS-CANCELLED)))
  )
)

;; Public functions

;; Submit a new grant application
(define-public (submit-application
  (title (string-ascii 200))
  (description (string-ascii 1000))
  (institution (string-ascii 100))
  (department (string-ascii 100))
  (budget-amount uint)
  (duration-days uint)
)
  (let
    (
      (grant-id (var-get next-grant-id))
      (current-block-height block-height)
    )
    ;; Validate inputs
    (asserts! (> (len title) u0) ERR-INVALID-INPUT)
    (asserts! (> (len description) u0) ERR-INVALID-INPUT)
    (asserts! (> (len institution) u0) ERR-INVALID-INPUT)
    (asserts! (> (len department) u0) ERR-INVALID-INPUT)
    (asserts! (> budget-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (and (> duration-days u0) (<= duration-days u1825)) ERR-INVALID-DURATION) ;; Max 5 years

    ;; Create grant record
    (map-set grants
      { grant-id: grant-id }
      {
        title: title,
        description: description,
        principal-investigator: tx-sender,
        institution: institution,
        department: department,
        budget-amount: budget-amount,
        duration-days: duration-days,
        status: STATUS-SUBMITTED,
        submission-date: current-block-height,
        approval-date: none,
        reviewer: none,
        start-date: none,
        end-date: none
      }
    )

    ;; Add principal investigator to investigators map
    (map-set grant-investigators
      { grant-id: grant-id, investigator: tx-sender }
      { role: "Principal Investigator", added-date: current-block-height }
    )

    ;; Increment grant ID counter
    (var-set next-grant-id (+ grant-id u1))

    (ok grant-id)
  )
)

;; Add co-investigator to a grant
(define-public (add-co-investigator (grant-id uint) (investigator principal) (role (string-ascii 50)))
  (let
    (
      (grant-data (unwrap! (get-grant grant-id) ERR-GRANT-NOT-FOUND))
      (current-block-height block-height)
    )
    ;; Only principal investigator can add co-investigators
    (asserts! (is-eq tx-sender (get principal-investigator grant-data)) ERR-NOT-AUTHORIZED)
    ;; Only for submitted or under-review grants
    (asserts! (or (is-eq (get status grant-data) STATUS-SUBMITTED)
                  (is-eq (get status grant-data) STATUS-UNDER-REVIEW)) ERR-INVALID-STATUS)
    ;; Validate role
    (asserts! (> (len role) u0) ERR-INVALID-INPUT)

    ;; Add co-investigator
    (map-set grant-investigators
      { grant-id: grant-id, investigator: investigator }
      { role: role, added-date: current-block-height }
    )

    (ok true)
  )
)

;; Update grant status (for reviewers)
(define-public (update-grant-status (grant-id uint) (new-status uint))
  (let
    (
      (grant-data (unwrap! (get-grant grant-id) ERR-GRANT-NOT-FOUND))
      (current-status (get status grant-data))
      (current-block-height block-height)
    )
    ;; Validate new status
    (asserts! (is-valid-status new-status) ERR-INVALID-STATUS)
    ;; Check if status transition is valid
    (asserts! (can-transition-status current-status new-status) ERR-INVALID-STATUS)
    ;; Only authorized reviewers can update status
    (asserts! (is-authorized-reviewer tx-sender) ERR-NOT-AUTHORIZED)

    ;; Update grant with new status
    (map-set grants
      { grant-id: grant-id }
      (merge grant-data {
        status: new-status,
        reviewer: (some tx-sender),
        approval-date: (if (is-eq new-status STATUS-APPROVED) (some current-block-height) none)
      })
    )

    (ok true)
  )
)

;; Approve grant and set active dates
(define-public (approve-grant (grant-id uint))
  (let
    (
      (grant-data (unwrap! (get-grant grant-id) ERR-GRANT-NOT-FOUND))
      (current-block-height block-height)
      (end-block (+ current-block-height (get duration-days grant-data)))
    )
    ;; Only authorized reviewers can approve
    (asserts! (is-authorized-reviewer tx-sender) ERR-NOT-AUTHORIZED)
    ;; Grant must be under review
    (asserts! (is-eq (get status grant-data) STATUS-UNDER-REVIEW) ERR-INVALID-STATUS)

    ;; Update grant to approved status with dates
    (map-set grants
      { grant-id: grant-id }
      (merge grant-data {
        status: STATUS-APPROVED,
        reviewer: (some tx-sender),
        approval-date: (some current-block-height),
        start-date: (some current-block-height),
        end-date: (some end-block)
      })
    )

    (ok true)
  )
)

;; Reject grant application
(define-public (reject-grant (grant-id uint))
  (let
    (
      (grant-data (unwrap! (get-grant grant-id) ERR-GRANT-NOT-FOUND))
      (current-block-height block-height)
    )
    ;; Only authorized reviewers can reject
    (asserts! (is-authorized-reviewer tx-sender) ERR-NOT-AUTHORIZED)
    ;; Grant must be under review
    (asserts! (is-eq (get status grant-data) STATUS-UNDER-REVIEW) ERR-INVALID-STATUS)

    ;; Update grant to rejected status
    (map-set grants
      { grant-id: grant-id }
      (merge grant-data {
        status: STATUS-REJECTED,
        reviewer: (some tx-sender)
      })
    )

    (ok true)
  )
)

;; Activate approved grant
(define-public (activate-grant (grant-id uint))
  (let
    (
      (grant-data (unwrap! (get-grant grant-id) ERR-GRANT-NOT-FOUND))
    )
    ;; Only principal investigator can activate
    (asserts! (is-eq tx-sender (get principal-investigator grant-data)) ERR-NOT-AUTHORIZED)
    ;; Grant must be approved
    (asserts! (is-eq (get status grant-data) STATUS-APPROVED) ERR-INVALID-STATUS)

    ;; Update grant to active status
    (map-set grants
      { grant-id: grant-id }
      (merge grant-data { status: STATUS-ACTIVE })
    )

    (ok true)
  )
)

;; Complete grant
(define-public (complete-grant (grant-id uint))
  (let
    (
      (grant-data (unwrap! (get-grant grant-id) ERR-GRANT-NOT-FOUND))
    )
    ;; Only principal investigator can complete
    (asserts! (is-eq tx-sender (get principal-investigator grant-data)) ERR-NOT-AUTHORIZED)
    ;; Grant must be active
    (asserts! (is-eq (get status grant-data) STATUS-ACTIVE) ERR-INVALID-STATUS)

    ;; Update grant to completed status
    (map-set grants
      { grant-id: grant-id }
      (merge grant-data { status: STATUS-COMPLETED })
    )

    (ok true)
  )
)

;; Admin functions

;; Add authorized reviewer
(define-public (add-authorized-reviewer (reviewer principal) (institution (string-ascii 100)))
  (let
    (
      (current-block-height block-height)
    )
    ;; Only contract admin can add reviewers
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR-NOT-AUTHORIZED)
    ;; Validate institution
    (asserts! (> (len institution) u0) ERR-INVALID-INPUT)

    ;; Add reviewer
    (map-set authorized-reviewers
      { reviewer: reviewer }
      { institution: institution, authorized-date: current-block-height, active: true }
    )

    (ok true)
  )
)

;; Remove authorized reviewer
(define-public (remove-authorized-reviewer (reviewer principal))
  (let
    (
      (reviewer-data (unwrap! (map-get? authorized-reviewers { reviewer: reviewer }) ERR-GRANT-NOT-FOUND))
    )
    ;; Only contract admin can remove reviewers
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR-NOT-AUTHORIZED)

    ;; Deactivate reviewer
    (map-set authorized-reviewers
      { reviewer: reviewer }
      (merge reviewer-data { active: false })
    )

    (ok true)
  )
)

;; Add institution admin
(define-public (add-institution-admin (admin principal) (institution (string-ascii 100)))
  (let
    (
      (current-block-height block-height)
    )
    ;; Only contract admin can add institution admins
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR-NOT-AUTHORIZED)
    ;; Validate institution
    (asserts! (> (len institution) u0) ERR-INVALID-INPUT)

    ;; Add institution admin
    (map-set institution-admins
      { admin: admin }
      { institution: institution, authorized-date: current-block-height, active: true }
    )

    (ok true)
  )
)

;; Transfer contract admin
(define-public (transfer-admin (new-admin principal))
  (begin
    ;; Only current admin can transfer
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR-NOT-AUTHORIZED)

    ;; Update admin
    (var-set contract-admin new-admin)

    (ok true)
  )
)
