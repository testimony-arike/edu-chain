;; Title: EduChain - Universal Academic Verification Protocol
;;
;; Summary:
;; A next-generation blockchain infrastructure for creating tamper-proof 
;; academic records that transcend institutional boundaries, enabling 
;; global verification of educational achievements with unprecedented 
;; security and accessibility.
;;
;; Description:
;; EduChain revolutionizes how educational credentials are issued, verified, 
;; and transferred across the globe. Built on Stacks with Bitcoin's rock-solid 
;; security foundation, this protocol creates an immutable ledger of academic 
;; achievements that no single institution can control or manipulate.
;;
;; Key innovations include:
;; - Trustless verification eliminating diploma mills and credential fraud
;; - Cross-institutional endorsement networks that strengthen credential value
;; - Granular permission systems allowing secure delegation of authority
;; - Automated batch processing for seamless institutional integration
;; - Dynamic reputation scoring that rewards quality educational providers
;; - Secure transfer protocols enabling credential portability across borders
;; - Expiration controls ensuring credentials remain current and relevant
;;
;; This system empowers students with true ownership of their academic records
;; while providing employers and institutions with instant, cryptographically
;; verified proof of educational accomplishments. The decentralized architecture
;; ensures that academic credentials remain accessible even if institutions
;; close or lose accreditation, creating a permanent, global academic registry.

;; SYSTEM CONSTANTS & ERROR CODES

(define-constant contract-owner tx-sender)

;; Error Constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ALREADY-REGISTERED (err u101))
(define-constant ERR-INSUFFICIENT-STAKE (err u102))
(define-constant ERR-CREDENTIAL-NOT-FOUND (err u103))
(define-constant ERR-ALREADY-VERIFIED (err u104))
(define-constant ERR-INVALID-STATUS (err u105))
(define-constant ERR-EXPIRED (err u106))
(define-constant ERR-BATCH-FAILED (err u107))
(define-constant ERR-TRANSFER-FAILED (err u108))
(define-constant ERR-INVALID-BATCH-SIZE (err u109))
(define-constant ERR-INVALID-DELEGATION (err u110))
(define-constant ERR-ALREADY-ENDORSED (err u111))
(define-constant ERR-INVALID-EXPIRY (err u112))
(define-constant ERR-INVALID-INPUT (err u113))
(define-constant ERR-EMPTY-STRING (err u120))

;; System Configuration
(define-constant MINIMUM-STAKE u1000000)
(define-constant MAX-BATCH-SIZE u50)

;; GLOBAL STATE VARIABLES

(define-data-var transfer-counter uint u0)
(define-data-var total-institutions uint u0)
(define-data-var governance-token-address principal 'SP000000000000000000002Q6VF78)

;; DATA STRUCTURES

;; Institution Registry
(define-map institutions
  principal
  {
    name: (string-ascii 64),
    stake-amount: uint,
    credentials-issued: uint,
    reputation-score: uint,
    active: bool,
    suspension-status: bool,
    registration-date: uint,
    last-update: uint,
  }
)

;; Credential Registry
(define-map credentials
  {
    id: (string-ascii 64),
    student: principal,
  }
  {
    institution: principal,
    degree: (string-ascii 64),
    year: uint,
    verified: bool,
    validation-level: uint,
    endorsements: uint,
    metadata-url: (string-ascii 256),
    expiry-date: uint,
    revoked: bool,
    category: (string-ascii 32),
    issue-date: uint,
    last-endorsed: uint,
  }
)

;; Endorsement System
(define-map endorsements
  {
    credential-id: (string-ascii 64),
    endorser: principal,
  }
  {
    timestamp: uint,
    weight: uint,
    comment: (string-ascii 256),
    endorser-type: (string-ascii 32),
  }
)

;; Delegation Management
(define-map institution-delegates
  {
    institution: principal,
    delegate: principal,
  }
  {
    active: bool,
    permissions: (list 10 (string-ascii 32)),
    added-at: uint,
    expiry: uint,
  }
)

;; Transfer Protocol
(define-map transfer-requests
  uint
  {
    credential-id: (string-ascii 64),
    old-owner: principal,
    new-owner: principal,
    status: (string-ascii 16),
    request-time: uint,
    expiry-time: uint,
    transfer-type: (string-ascii 32),
  }
)

;; INPUT VALIDATION FUNCTIONS

(define-private (validate-non-empty-string (input (string-ascii 64)))
  (> (len input) u0)
)

(define-private (validate-url (url (string-ascii 256)))
  (and
    (> (len url) u0)
    true
  )
)

(define-private (validate-year (year uint))
  (and
    (> year u1900)
    (< year (+ u2100 u1))
  )
)

(define-private (validate-expiry (expiry uint))
  (> expiry stacks-block-height)
)

(define-private (validate-credential-id (credential-id (string-ascii 64)))
  (and
    (> (len credential-id) u0)
    true
  )
)

(define-private (validate-permissions (permissions (list 10 (string-ascii 32))))
  (and
    (> (len permissions) u0)
    true
  )
)

(define-private (validate-endorsement-weight (weight uint))
  (and
    (>= weight u1)
    (<= weight u100)
  )
)

(define-private (validate-principal (address principal))
  (not (is-eq address tx-sender))
)

(define-private (validate-student (student-address principal))
  (not (is-eq student-address tx-sender))
)

(define-private (validate-comment (comment-text (string-ascii 256)))
  (<= (len comment-text) u200)
)

;; INSTITUTION MANAGEMENT

(define-public (register-institution (name (string-ascii 64)))
  (let ((caller tx-sender))
    (asserts!
      (not (default-to false (get active (map-get? institutions caller))))
      ERR-ALREADY-REGISTERED
    )
    (asserts! (validate-non-empty-string name) ERR-EMPTY-STRING)
    (try! (stx-transfer? MINIMUM-STAKE caller (as-contract tx-sender)))
    (map-set institutions caller {
      name: name,
      stake-amount: MINIMUM-STAKE,
      credentials-issued: u0,
      reputation-score: u100,
      active: true,
      suspension-status: false,
      registration-date: stacks-block-height,
      last-update: stacks-block-height,
    })
    (var-set total-institutions (+ (var-get total-institutions) u1))
    (ok true)
  )
)

(define-public (add-delegate
    (delegate-address principal)
    (permissions (list 10 (string-ascii 32)))
    (expiry uint)
  )
  (let ((institution tx-sender))
    (asserts! (is-institution institution) ERR-NOT-AUTHORIZED)
    (asserts! (validate-permissions permissions) ERR-INVALID-INPUT)
    (asserts! (validate-expiry expiry) ERR-INVALID-EXPIRY)
    (asserts! (validate-principal delegate-address) ERR-INVALID-DELEGATION)
    (map-set institution-delegates {
      institution: institution,
      delegate: delegate-address,
    } {
      active: true,
      permissions: permissions,
      added-at: stacks-block-height,
      expiry: expiry,
    })
    (ok true)
  )
)

;; CREDENTIAL ISSUANCE & MANAGEMENT

(define-public (issue-credential
    (credential-id (string-ascii 64))
    (student principal)
    (degree (string-ascii 64))
    (year uint)
    (metadata-url (string-ascii 256))
    (expiry-date uint)
    (category (string-ascii 32))
  )
  (let (
      (institution tx-sender)
      (inst-data (unwrap! (map-get? institutions institution) ERR-NOT-AUTHORIZED))
    )
    (asserts! (get active inst-data) ERR-NOT-AUTHORIZED)
    (asserts! (not (get suspension-status inst-data)) ERR-INVALID-STATUS)
    (asserts! (validate-credential-id credential-id) ERR-INVALID-INPUT)
    (asserts! (validate-non-empty-string degree) ERR-INVALID-INPUT)
    (asserts! (validate-year year) ERR-INVALID-INPUT)
    (asserts! (validate-url metadata-url) ERR-INVALID-INPUT)
    (asserts! (validate-expiry expiry-date) ERR-INVALID-EXPIRY)
    (asserts! (validate-non-empty-string category) ERR-INVALID-INPUT)
    (asserts! (validate-student student) ERR-INVALID-INPUT)
    (map-set credentials {
      id: credential-id,
      student: student,
    } {
      institution: institution,
      degree: degree,
      year: year,
      verified: true,
      validation-level: u0,
      endorsements: u0,
      metadata-url: metadata-url,
      expiry-date: expiry-date,
      revoked: false,
      category: category,
      issue-date: stacks-block-height,
      last-endorsed: u0,
    })
    (map-set institutions institution
      (merge inst-data {
        credentials-issued: (+ (get credentials-issued inst-data) u1),
        last-update: stacks-block-height,
      })
    )
    (ok true)
  )
)

(define-public (batch-issue-credentials
    (credential-ids (list 50 (string-ascii 64)))
    (students (list 50 principal))
    (degrees (list 50 (string-ascii 64)))
    (years (list 50 uint))
    (metadata-urls (list 50 (string-ascii 256)))
    (expiry-dates (list 50 uint))
    (categories (list 50 (string-ascii 32)))
  )
  (let (
      (institution tx-sender)
      (batch-size (len credential-ids))
    )
    (asserts! (<= batch-size MAX-BATCH-SIZE) ERR-INVALID-BATCH-SIZE)
    (asserts! (is-institution institution) ERR-NOT-AUTHORIZED)
    ;; Validate input lengths match
    (asserts!
      (and
        (is-eq batch-size (len students))
        (is-eq batch-size (len degrees))
        (is-eq batch-size (len years))
        (is-eq batch-size (len metadata-urls))
        (is-eq batch-size (len expiry-dates))
        (is-eq batch-size (len categories))
      )
      ERR-INVALID-BATCH-SIZE
    )
    ;; Validate each expiry date
    (asserts! (fold check-all-expiry-dates expiry-dates true) ERR-INVALID-EXPIRY)
    (ok (map process-credential-issuance credential-ids students degrees years
      metadata-urls expiry-dates categories
    ))
  )
)

;; ENDORSEMENT SYSTEM

(define-public (endorse-credential-extended
    (credential-id (string-ascii 64))
    (student principal)
    (weight uint)
    (comment (string-ascii 256))
    (endorser-type (string-ascii 32))
  )
  (let (
      (endorser tx-sender)
      (credential (unwrap!
        (map-get? credentials {
          id: credential-id,
          student: student,
        })
        ERR-CREDENTIAL-NOT-FOUND
      ))
      (endorser-data (unwrap! (map-get? institutions endorser) ERR-NOT-AUTHORIZED))
    )
    (asserts! (get active endorser-data) ERR-NOT-AUTHORIZED)
    (asserts! (not (get revoked credential)) ERR-INVALID-STATUS)
    (asserts! (< stacks-block-height (get expiry-date credential)) ERR-EXPIRED)
    (asserts! (validate-credential-id credential-id) ERR-INVALID-INPUT)
    (asserts! (validate-endorsement-weight weight) ERR-INVALID-INPUT)
    (asserts! (validate-non-empty-string endorser-type) ERR-INVALID-INPUT)
    (asserts! (validate-comment comment) ERR-INVALID-INPUT)
    ;; Check if already endorsed by this endorser
    (asserts!
      (is-none (map-get? endorsements {
        credential-id: credential-id,
        endorser: endorser,
      }))
      ERR-ALREADY-ENDORSED
    )
    (map-set endorsements {
      credential-id: credential-id,
      endorser: endorser,
    } {
      timestamp: stacks-block-height,
      weight: weight,
      comment: comment,
      endorser-type: endorser-type,
    })
    (map-set credentials {
      id: credential-id,
      student: student,
    }
      (merge credential {
        endorsements: (+ (get endorsements credential) u1),
        last-endorsed: stacks-block-height,
      })
    )
    (map-set institutions (get institution credential)
      (merge endorser-data {
        reputation-score: (+ (get reputation-score endorser-data) weight),
        last-update: stacks-block-height,
      })
    )
    (ok true)
  )
)

;; TRANSFER PROTOCOL

(define-public (request-credential-transfer
    (credential-id (string-ascii 64))
    (new-owner principal)
    (transfer-type (string-ascii 32))
    (expiry-time uint)
  )
  (let (
      (transfer-id (var-get transfer-counter))
      (credential (unwrap!
        (map-get? credentials {
          id: credential-id,
          student: tx-sender,
        })
        ERR-CREDENTIAL-NOT-FOUND
      ))
    )
    (asserts! (not (get revoked credential)) ERR-INVALID-STATUS)
    (asserts! (validate-expiry expiry-time) ERR-INVALID-EXPIRY)
    (asserts! (validate-credential-id credential-id) ERR-INVALID-INPUT)
    (asserts! (validate-non-empty-string transfer-type) ERR-INVALID-INPUT)
    (asserts! (not (is-eq tx-sender new-owner)) ERR-INVALID-INPUT)
    (map-set transfer-requests transfer-id {
      credential-id: credential-id,
      old-owner: tx-sender,
      new-owner: new-owner,
      status: "pending",
      request-time: stacks-block-height,
      expiry-time: expiry-time,
      transfer-type: transfer-type,
    })
    (var-set transfer-counter (+ transfer-id u1))
    (ok transfer-id)
  )
)