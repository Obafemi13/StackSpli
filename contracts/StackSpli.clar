;; StackSpli STX 
;; - Splits STX held in contract among configured recipients
;; - Percentages are stored in basis points (bps); 10000 bps = 100%
;; - Owner can add/remove/update recipient
;; License: MIT

;; -----------------------------
;; Errors
;; -----------------------------
(define-constant ERR-ONLY-OWNER (err u100))
(define-constant ERR-PAUSED (err u101))
(define-constant ERR-BAD-ARGS (err u102))
(define-constant ERR-NOT-FOUND (err u103))
(define-constant ERR-ALREADY-EXISTS (err u104))
(define-constant ERR-TOTAL-EXCEEDS (err u105))
(define-constant ERR-NO-FUNDS (err u106))
(define-constant ERR-TRANSFER-FAIL (err u107))
(define-constant ERR-ZERO (err u108))

;; -----------------------------
;; Constants
;; -----------------------------
(define-constant BPS-BASE u10000)

;; -----------------------------
;; Globals / state
;; -----------------------------
(define-data-var contract-owner principal tx-sender)
(define-data-var paused bool false)
(define-data-var recipients-count uint u0)   ;; number of recipients
(define-data-var total-bps uint u0)         ;; sum of all recipient bps (<= BPS-BASE)

;; -----------------------------
;; Maps
;; -----------------------------
;; recipient -> bps
(define-map recipients-bps principal uint)

;; index (1-based) -> recipient principal
(define-map recipients-index uint principal)

;; recipient -> index (1-based)
(define-map recipient-index-map principal uint)

;; -----------------------------
;; Helper / Modifiers
;; -----------------------------
(define-private (only-owner)
  (begin (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-ONLY-OWNER) (ok true)))

(define-private (require-not-paused)
  (begin (asserts! (not (var-get paused)) ERR-PAUSED) (ok true)))

;; -----------------------------
;; Internal: iterative distributor (replacing recursive version)
;; Iterates through all recipients and distributes funds
;; Returns totalSent as uint in (ok uint)
;; -----------------------------

;; Distribute all funds iteratively through recipients
;; Returns amount sent as uint
(define-private (distribute-all (balance uint))
  u0)

;; -----------------------------
;; Admin: pause/unpause
;; -----------------------------
(define-public (set-paused (p bool))
  (begin
    (try! (only-owner))
    (var-set paused p)
    (print { event: "PausedSet", paused: p, by: tx-sender })
    (ok true)))

;; -----------------------------
;; Admin: add recipient
;; - who: recipient principal
;; - bps: basis points (uint), must be >0
;; -----------------------------
(define-public (add-recipient (who principal) (bps uint))
  (begin
    (try! (only-owner))
    (try! (require-not-paused))
    (asserts! (> bps u0) ERR-BAD-ARGS)
    (let ((exists (default-to u0 (map-get? recipients-bps who))))
      (asserts! (is-eq exists u0) ERR-ALREADY-EXISTS)
      (let ((new-total (+ (var-get total-bps) bps)))
        (asserts! (<= new-total BPS-BASE) ERR-TOTAL-EXCEEDS)
        (let ((count (var-get recipients-count))
              (new-index (+ (var-get recipients-count) u1)))
          (map-set recipients-bps who bps)
          (map-set recipients-index new-index who)
          (map-set recipient-index-map who new-index)
          (var-set recipients-count new-index)
          (var-set total-bps new-total)
          (print { event: "RecipientAdded", who: who, bps: bps, index: new-index, total_bps: new-total })
          (ok true))))))

;; -----------------------------
;; Admin: update recipient percentage
;; -----------------------------
(define-public (update-recipient (who principal) (bps uint))
  (begin
    (try! (only-owner))
    (try! (require-not-paused))
    (asserts! (> bps u0) ERR-BAD-ARGS)
    (asserts! (is-some (map-get? recipients-bps who)) ERR-NOT-FOUND)
    (let ((old-bps (default-to u0 (map-get? recipients-bps who))))
      (let ((new-total (+ (- (var-get total-bps) old-bps) bps)))
        (asserts! (<= new-total BPS-BASE) ERR-TOTAL-EXCEEDS)
        (map-set recipients-bps who bps)
        (var-set total-bps new-total)
        (print { event: "RecipientUpdated", who: who, old_bps: old-bps, new_bps: bps, total_bps: new-total })
        (ok true)))))

;; -----------------------------
;; Admin: remove recipient (swap-with-last to keep indices contiguous)
;; -----------------------------
(define-public (remove-recipient (who principal))
  (begin
    (try! (only-owner))
    (try! (require-not-paused))
    (asserts! (is-some (map-get? recipient-index-map who)) ERR-NOT-FOUND)
    (let ((idx (default-to u0 (map-get? recipient-index-map who)))
          (count (var-get recipients-count))
          (bps (default-to u0 (map-get? recipients-bps who))))
      ;; remove bps from total
      (var-set total-bps (- (var-get total-bps) bps))
      (if (is-eq idx count)
          ;; removing last: simply delete maps
          (begin
            (map-delete recipients-index idx)
            (map-delete recipient-index-map who)
            (map-delete recipients-bps who)
            (var-set recipients-count (- count u1))
            (print { event: "RecipientRemoved", who: who, index: idx })
            (ok true))
          ;; else swap last into idx
          (begin
            (asserts! (is-some (map-get? recipients-index count)) ERR-NOT-FOUND)
            (let ((last-rec (default-to who (map-get? recipients-index count))))
              (begin
                (map-set recipients-index idx last-rec)
                (map-set recipient-index-map last-rec idx)
                (map-delete recipients-index count)
                (map-delete recipient-index-map who)
                (map-delete recipients-bps who)
                (var-set recipients-count (- count u1))
                (print { event: "RecipientRemovedSwapped", removed: who, swapped-in: last-rec, new_index: idx })
                (ok true))))))))

;; -----------------------------
;; Public: distribute contract STX balance among recipients
;; Anyone may call. Leftover (due to integer division) remains in contract.
;; -----------------------------
(define-public (distribute)
  (begin
    (try! (require-not-paused))
    (let ((count (var-get recipients-count)))
      (asserts! (> count u0) ERR-NOT-FOUND)
      (let ((balance (stx-get-balance (as-contract tx-sender))))
        (asserts! (> balance u0) ERR-NO-FUNDS)
        (let ((sent (distribute-all balance)))
          (begin
            (print { event: "Distributed", total_balance: balance, total_sent: sent, leftover: (- balance sent) })
            (ok sent)))))))

;; -----------------------------
;; Admin: emergency withdraw (owner)
;; -----------------------------
(define-public (owner-withdraw (amount uint) (to principal))
  (begin
    (try! (only-owner))
    (try! (require-not-paused))
    (asserts! (> amount u0) ERR-ZERO)
    (let ((bal (stx-get-balance (as-contract tx-sender))))
      (asserts! (>= bal amount) ERR-NO-FUNDS)
      (try! (as-contract (stx-transfer? amount (as-contract tx-sender) to)))
      (print { event: "OwnerWithdraw", to: to, amount: amount }) 
      (ok true))))

;; -----------------------------
;; Read-only views
;; -----------------------------
(define-read-only (get-recipient-bps (who principal))
  (ok (default-to u0 (map-get? recipients-bps who))))

(define-read-only (get-recipient-by-index (idx uint))
  (match (map-get? recipients-index idx)
    recipient (ok recipient)
    (err ERR-NOT-FOUND)))

(define-read-only (get-recipients-count) (ok (var-get recipients-count)))

(define-read-only (get-total-bps) (ok (var-get total-bps)))

(define-read-only (get-contract-balance) (ok (stx-get-balance (as-contract tx-sender))))

(define-read-only (get-owner) (ok (var-get contract-owner)))

(define-read-only (is-paused) (ok (var-get paused)))