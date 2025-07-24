;; Adaptive Capacity Enhancement Contract
;; Improves ability to thrive in changing circumstances

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-INVALID-INPUT (err u201))
(define-constant ERR-SCENARIO-NOT-FOUND (err u202))
(define-constant ERR-INSUFFICIENT-CAPACITY (err u203))
(define-constant ERR-COOLDOWN-ACTIVE (err u204))

;; Helper functions
(define-private (min-uint (a uint) (b uint))
  (if (<= a b) a b)
)

(define-private (max-uint (a uint) (b uint))
  (if (>= a b) a b)
)

;; Data Variables
(define-data-var next-scenario-id uint u1)
(define-data-var adaptation-multiplier uint u100)

;; Data Maps
(define-map adaptation-scenarios
  { scenario-id: uint }
  {
    name: (string-ascii 60),
    change-type: (string-ascii 30),
    complexity-level: uint,
    adaptation-window: uint,
    success-criteria: (string-ascii 120),
    base-reward: uint,
    active: bool
  }
)

(define-map user-adaptability
  { user: principal }
  {
    flexibility-score: uint,
    pivot-speed: uint,
    learning-rate: uint,
    change-comfort: uint,
    total-adaptations: uint,
    adapt-tokens: uint,
    last-adaptation-block: uint
  }
)

(define-map scenario-attempts
  { user: principal, scenario-id: uint }
  {
    attempts: uint,
    best-performance: uint,
    adaptation-time: uint,
    strategy-changes: uint,
    completed: bool
  }
)

(define-map adaptation-strategies
  { user: principal, scenario-id: uint, attempt: uint }
  {
    strategy-description: (string-ascii 100),
    effectiveness-rating: uint,
    time-to-implement: uint,
    resource-efficiency: uint
  }
)

;; Read-only functions
(define-read-only (get-scenario (scenario-id uint))
  (map-get? adaptation-scenarios { scenario-id: scenario-id })
)

(define-read-only (get-user-adaptability (user principal))
  (default-to
    { flexibility-score: u50, pivot-speed: u50, learning-rate: u50, change-comfort: u50, total-adaptations: u0, adapt-tokens: u0, last-adaptation-block: u0 }
    (map-get? user-adaptability { user: user })
  )
)

(define-read-only (get-scenario-attempts (user principal) (scenario-id uint))
  (default-to
    { attempts: u0, best-performance: u0, adaptation-time: u0, strategy-changes: u0, completed: false }
    (map-get? scenario-attempts { user: user, scenario-id: scenario-id })
  )
)

(define-read-only (calculate-adaptability-index (user principal))
  (let ((adaptability (get-user-adaptability user)))
    (/ (+ (get flexibility-score adaptability)
          (get pivot-speed adaptability)
          (get learning-rate adaptability)
          (get change-comfort adaptability)) u4)
  )
)

(define-read-only (get-adaptation-cooldown (user principal))
  (let ((adaptability (get-user-adaptability user)))
    (if (> (get last-adaptation-block adaptability) u0)
      (if (> (+ (get last-adaptation-block adaptability) u144) block-height)
        (- (+ (get last-adaptation-block adaptability) u144) block-height)
        u0)
      u0)
  )
)

;; Public functions
(define-public (create-adaptation-scenario
  (name (string-ascii 60))
  (change-type (string-ascii 30))
  (complexity-level uint)
  (adaptation-window uint)
  (success-criteria (string-ascii 120))
  (base-reward uint)
)
  (let ((scenario-id (var-get next-scenario-id)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (and (> complexity-level u0) (<= complexity-level u10)) ERR-INVALID-INPUT)
    (asserts! (> adaptation-window u0) ERR-INVALID-INPUT)

    (map-set adaptation-scenarios
      { scenario-id: scenario-id }
      {
        name: name,
        change-type: change-type,
        complexity-level: complexity-level,
        adaptation-window: adaptation-window,
        success-criteria: success-criteria,
        base-reward: base-reward,
        active: true
      }
    )

    (var-set next-scenario-id (+ scenario-id u1))
    (ok scenario-id)
  )
)

(define-public (begin-adaptation (scenario-id uint))
  (let (
    (scenario (unwrap! (get-scenario scenario-id) ERR-SCENARIO-NOT-FOUND))
    (user-adapt (get-user-adaptability tx-sender))
    (cooldown (get-adaptation-cooldown tx-sender))
  )
    (asserts! (get active scenario) ERR-SCENARIO-NOT-FOUND)
    (asserts! (is-eq cooldown u0) ERR-COOLDOWN-ACTIVE)
    (asserts! (>= (calculate-adaptability-index tx-sender) (* (get complexity-level scenario) u8)) ERR-INSUFFICIENT-CAPACITY)

    ;; Initialize user adaptability if needed
    (if (is-eq (get total-adaptations user-adapt) u0)
      (map-set user-adaptability
        { user: tx-sender }
        user-adapt
      )
      true
    )

    ;; Initialize scenario attempt
    (map-set scenario-attempts
      { user: tx-sender, scenario-id: scenario-id }
      { attempts: u1, best-performance: u0, adaptation-time: u0, strategy-changes: u0, completed: false }
    )

    (ok true)
  )
)

(define-public (record-adaptation-strategy
  (scenario-id uint)
  (attempt uint)
  (strategy-description (string-ascii 100))
  (effectiveness-rating uint)
  (time-to-implement uint)
  (resource-efficiency uint)
)
  (let ((scenario (unwrap! (get-scenario scenario-id) ERR-SCENARIO-NOT-FOUND)))
    (asserts! (and (>= effectiveness-rating u1) (<= effectiveness-rating u100)) ERR-INVALID-INPUT)
    (asserts! (and (>= resource-efficiency u1) (<= resource-efficiency u100)) ERR-INVALID-INPUT)
    (asserts! (> time-to-implement u0) ERR-INVALID-INPUT)

    (map-set adaptation-strategies
      { user: tx-sender, scenario-id: scenario-id, attempt: attempt }
      {
        strategy-description: strategy-description,
        effectiveness-rating: effectiveness-rating,
        time-to-implement: time-to-implement,
        resource-efficiency: resource-efficiency
      }
    )

    (ok true)
  )
)

(define-public (complete-adaptation
  (scenario-id uint)
  (final-performance uint)
  (total-adaptation-time uint)
  (strategy-changes uint)
)
  (let (
    (scenario (unwrap! (get-scenario scenario-id) ERR-SCENARIO-NOT-FOUND))
    (user-adapt (get-user-adaptability tx-sender))
    (attempts (get-scenario-attempts tx-sender scenario-id))
  )
    (asserts! (and (>= final-performance u1) (<= final-performance u100)) ERR-INVALID-INPUT)
    (asserts! (> total-adaptation-time u0) ERR-INVALID-INPUT)
    (asserts! (not (get completed attempts)) ERR-INVALID-INPUT)

    ;; Update scenario attempts
    (map-set scenario-attempts
      { user: tx-sender, scenario-id: scenario-id }
      (merge attempts {
        best-performance: final-performance,
        adaptation-time: total-adaptation-time,
        strategy-changes: strategy-changes,
        completed: true
      })
    )

    ;; Calculate improvements
    (let (
      (speed-bonus (if (<= total-adaptation-time (get adaptation-window scenario)) u20 u0))
      (performance-bonus (/ final-performance u5))
      (flexibility-bonus (min-uint strategy-changes u15))
      (total-bonus (+ speed-bonus performance-bonus flexibility-bonus))

      (new-flexibility (min-uint (+ (get flexibility-score user-adapt) flexibility-bonus) u100))
      (new-pivot-speed (min-uint (+ (get pivot-speed user-adapt) speed-bonus) u100))
      (new-learning-rate (min-uint (+ (get learning-rate user-adapt) (/ performance-bonus u2)) u100))
      (new-change-comfort (min-uint (+ (get change-comfort user-adapt) u5) u100))
      (reward-amount (* (get base-reward scenario) (+ u100 total-bonus) (var-get adaptation-multiplier)))
    )
      ;; Update user adaptability
      (map-set user-adaptability
        { user: tx-sender }
        {
          flexibility-score: new-flexibility,
          pivot-speed: new-pivot-speed,
          learning-rate: new-learning-rate,
          change-comfort: new-change-comfort,
          total-adaptations: (+ (get total-adaptations user-adapt) u1),
          adapt-tokens: (+ (get adapt-tokens user-adapt) (/ reward-amount u10000)),
          last-adaptation-block: block-height
        }
      )

      (ok (/ reward-amount u10000))
    )
  )
)

(define-public (update-adaptation-multiplier (new-multiplier uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (and (>= new-multiplier u50) (<= new-multiplier u200)) ERR-INVALID-INPUT)
    (var-set adaptation-multiplier new-multiplier)
    (ok new-multiplier)
  )
)

;; Initialize sample scenarios
(define-private (init-sample-scenarios)
  (begin
    (unwrap-panic (create-adaptation-scenario "Market Shift Response" "economic" u3 u1008 "Pivot business model within 1 week" u200))
    (unwrap-panic (create-adaptation-scenario "Technology Disruption" "technological" u5 u2016 "Integrate new tech stack in 2 weeks" u350))
    (unwrap-panic (create-adaptation-scenario "Team Restructure" "organizational" u4 u720 "Reorganize workflow in 5 days" u275))
    (unwrap-panic (create-adaptation-scenario "Regulatory Change" "compliance" u6 u1440 "Update processes for new regulations" u400))
  )
)

;; Initialize on deployment
(init-sample-scenarios)
