# StackSpli Smart Contract README

````markdown
# StackSpli

A Stacks smart contract for splitting STX among configured recipients using basis point allocations.

## Overview

StackSpli automates the distribution of STX held in a contract across multiple recipients. Recipients are allocated percentages in basis points (bps), where 10,000 bps = 100%. This enables flexible, programmable revenue sharing and fund distribution.

## Features

- **Recipient Management**: Add, update, and remove recipients with custom basis point allocations
- **Flexible Distribution**: Distribute STX proportionally among all configured recipients
- **Pause/Unpause**: Owner can pause/unpause contract operations for maintenance
- **Emergency Withdrawal**: Owner can withdraw funds in emergency situations
- **Efficient Removal**: Uses swap-with-last algorithm for O(1) recipient removal
- **Event Logging**: Comprehensive event emission for all state changes
- **Validation**: Ensures total basis points never exceed 100%

## Contract Functions

### Admin Functions

#### `set-paused (p: bool) -> (response bool)`
Pause or unpause contract operations. Only owner can call.

```clarity
(contract-call? .stackspli set-paused true)
```

#### `add-recipient (who: principal) (bps: uint) -> (response bool)`
Add a new recipient with specified basis point allocation. Only owner can call.

```clarity
(contract-call? .stackspli add-recipient 'SP2JXKMH002PY2F4X2YNVDRNN92AAGQGZ4P5K8C5 u5000)
```

**Parameters:**
- `who`: Principal address of recipient
- `bps`: Basis points allocation (e.g., 5000 = 50%)

**Errors:**
- `ERR-ONLY-OWNER` (100): Caller is not contract owner
- `ERR-PAUSED` (101): Contract is paused
- `ERR-BAD-ARGS` (102): Invalid basis points (must be > 0)
- `ERR-ALREADY-EXISTS` (104): Recipient already configured
- `ERR-TOTAL-EXCEEDS` (105): Total bps would exceed 100%

#### `update-recipient (who: principal) (bps: uint) -> (response bool)`
Update an existing recipient's basis point allocation. Only owner can call.

```clarity
(contract-call? .stackspli update-recipient 'SP2JXKMH002PY2F4X2YNVDRNN92AAGQGZ4P5K8C5 u7500)
```

**Errors:**
- `ERR-ONLY-OWNER` (100)
- `ERR-PAUSED` (101)
- `ERR-BAD-ARGS` (102)
- `ERR-NOT-FOUND` (103): Recipient not found
- `ERR-TOTAL-EXCEEDS` (105)

#### `remove-recipient (who: principal) -> (response bool)`
Remove a recipient from distribution. Only owner can call.

```clarity
(contract-call? .stackspli remove-recipient 'SP2JXKMH002PY2F4X2YNVDRNN92AAGQGZ4P5K8C5)
```

**Errors:**
- `ERR-ONLY-OWNER` (100)
- `ERR-PAUSED` (101)
- `ERR-NOT-FOUND` (103)

#### `owner-withdraw (amount: uint) (to: principal) -> (response bool)`
Emergency withdrawal of funds by owner. Only owner can call.

```clarity
(contract-call? .stackspli owner-withdraw u1000000 'SP2JXKMH002PY2F4X2YNVDRNN92AAGQGZ4P5K8C5)
```

**Errors:**
- `ERR-ONLY-OWNER` (100)
- `ERR-PAUSED` (101)
- `ERR-ZERO` (108): Amount must be > 0
- `ERR-NO-FUNDS` (106): Insufficient contract balance

### Public Functions

#### `distribute () -> (response uint)`
Distribute all STX among configured recipients. Anyone can call.

```clarity
(contract-call? .stackspli distribute)
```

**Returns:** Total STX amount sent to recipients

**Errors:**
- `ERR-PAUSED` (101)
- `ERR-NOT-FOUND` (103): No recipients configured
- `ERR-NO-FUNDS` (106): No funds in contract

### Read-Only Functions

#### `get-recipient-bps (who: principal) -> (response uint)`
Query a recipient's basis point allocation.

```clarity
(contract-call? .stackspli get-recipient-bps 'SP2JXKMH002PY2F4X2YNVDRNN92AAGQGZ4P5K8C5)
```

#### `get-recipient-by-index (idx: uint) -> (response principal)`
Lookup recipient by index (1-based).

```clarity
(contract-call? .stackspli get-recipient-by-index u1)
```

#### `get-recipients-count () -> (response uint)`
Get total number of configured recipients.

```clarity
(contract-call? .stackspli get-recipients-count)
```

#### `get-total-bps () -> (response uint)`
Get sum of all recipient basis points.

```clarity
(contract-call? .stackspli get-total-bps)
```

#### `get-contract-balance () -> (response uint)`
Get current STX balance held by contract.

```clarity
(contract-call? .stackspli get-contract-balance)
```

#### `get-owner () -> (response principal)`
Get contract owner address.

```clarity
(contract-call? .stackspli get-owner)
```

#### `is-paused () -> (response bool)`
Check if contract is paused.

```clarity
(contract-call? .stackspli is-paused)
```

## Usage Example

```clarity
;; Setup: Add two recipients (60% and 40% split)
(contract-call? .stackspli add-recipient 'SP2JXKMH002PY2F4X2YNVDRNN92AAGQGZ4P5K8C5 u6000)
(contract-call? .stackspli add-recipient 'SP3NE50GEXFG69CBQX3AWEBXEY08Q5Y4SHYBP5ANT u4000)

;; Anyone can call distribute when contract has STX
(contract-call? .stackspli distribute)
;; Result: First recipient gets 60% of balance, second gets 40%
```

## Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `BPS-BASE` | u10000 | 100% in basis points |

## Error Codes

| Code | Constant | Reason |
|------|----------|--------|
| 100 | ERR-ONLY-OWNER | Only owner can call |
| 101 | ERR-PAUSED | Contract is paused |
| 102 | ERR-BAD-ARGS | Invalid arguments |
| 103 | ERR-NOT-FOUND | Recipient not found |
| 104 | ERR-ALREADY-EXISTS | Recipient already exists |
| 105 | ERR-TOTAL-EXCEEDS | Total bps > 100% |
| 106 | ERR-NO-FUNDS | Insufficient funds |
| 107 | ERR-TRANSFER-FAIL | STX transfer failed |
| 108 | ERR-ZERO | Amount is zero |

## Implementation Notes

- **Basis Points**: All percentages use basis points (1 bps = 0.01%)
- **Swap-with-Last**: Recipient removal uses an efficient O(1) swap-with-last algorithm
- **Integer Division**: Remainders from distribution stay in contract (due to integer math)
- **1-Based Indexing**: Recipients are indexed starting from 1
- **Event Logging**: All state changes emit events for off-chain tracking

## Events

The contract emits events for:
- `PausedSet`: Pause state changed
- `RecipientAdded`: New recipient added
- `RecipientUpdated`: Recipient allocation updated
- `RecipientRemoved`: Recipient removed (direct deletion)
- `RecipientRemovedSwapped`: Recipient removed (swap operation)
- `Distributed`: STX distribution completed
- `OwnerWithdraw`: Owner withdrawal executed

## License

MIT

## Future Enhancements

- [ ] Implement `distribute-all` iteration logic for actual STX transfers
- [ ] Add recipient update notifications
- [ ] Support for SIP-010 token distribution
- [ ] Multi-signature owner control
- [ ] Vesting schedules for recipients

````
