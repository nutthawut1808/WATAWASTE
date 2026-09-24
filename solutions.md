# Solutions & Assessment Deliverables — Rescu

## 1. Bug Tickets Analysis & Fixes

---

### RES-104 · Duplicate deals in the home feed

* **Root Cause:** A race condition occurred between pagination (`loadMore`) and pull-to-refresh (`refreshDeals`). When a user pulled to refresh while pagination was actively fetching the next page, the pagination response completed *after* the feed was reset to page 1. Items from page N were subsequently appended to the freshly loaded page 1 list, resulting in duplicate items and exceeding total catalog counts.
* **Fix & Rationale:** Introduced a `_fetchVersion` counter that increments on every refresh operation, alongside an `_isFetchingMore` lock flag. When any asynchronous fetch completes, it checks if `currentVersion == _fetchVersion`. If a refresh occurred while the request was in flight, the outdated pagination payload is discarded immediately.
* **Alternatives Considered:** 
  * *Debouncing refresh during pagination:* Rejected because a pull-to-refresh is an explicit user intent to clear and update state; ignoring or delaying it creates an unresponsive UI experience.

---

### RES-105 · Home feed is janky and memory keeps climbing

* **Root Cause:** 
  1. **Over-broad Reactivity:** Wrapping large composite widgets or entire list subtrees inside a single `Obx` forced Flutter to re-render extensive widget hierarchies on every minor state update.
  2. **Unconstrained Image Caching:** Network images loaded full-resolution assets into memory without specifying `memCacheWidth` / `memCacheHeight`, causing memory ballooning as the user scrolled through long lists.
* **Fix & Rationale:** 
  1. Scope `Obx` tightly around only the specific leaf widgets that depend on observable state (e.g., `quantityLeft`, `isToday` status).
  2. Replaced `ListView.builder` / standard widgets with `SliverList.builder` and added explicit `memCacheWidth` constraints to image components (`TheNetworkImage`) to bound memory allocations.
* **Alternatives Considered:** 
  * *Disabling image caching entirely:* Rejected because it increases network consumption and introduces visual flickering during scrolling.

---

### RES-106 · Wrong pickup times; "Pickup today" filter misses deals

* **Root Cause:**
  1. **Timezone Misalignment:** The API sends ISO-8601 UTC timestamp strings. `DateTime.parse()` parses these as UTC, but they were formatted directly to string (`DateFormat('HH:mm')`) without converting to local time (`.toLocal()`). On UTC+7 timezone, times appeared shifted by 7 hours (e.g., 06:00 became 23:00 of the previous day).
  2. **Incomplete Date Comparison:** `PickupWindowModel.isToday` only checked `start.day == DateTime.now().day`. Comparing a UTC `.day` against a local `.day` failed around midnight, and comparing `.day` alone incorrectly matched identical calendar days in different months or years.
* **Fix & Rationale:** 
  1. Converted timestamps using `.toLocal()` inside `PickupWindowModel.fromJson()` and model methods.
  2. Refactored `isToday` to check `year`, `month`, and `day` on local timestamps against `DateTime.now()`.
* **Alternatives Considered:** 
  * *Applying `.toLocal()` only in the UI Widget layer:* Rejected because domain logic methods like `isToday`, `isOpenNow`, and `untilStart` inside the model would remain broken if the underlying model fields contained unconverted UTC times.

---

### RES-107 · Deep link opens to a crash

* **Root Cause:** `DealDetailsController.onInit()` explicitly cast `Get.arguments as DealModel`[cite: 3]. When navigating via deep link (`rescu://open/deal?id=42&source=push`)[cite: 2], parameters are passed via URL query parameters (`Get.parameters['id']`) and `Get.arguments` is `null`, triggering a `type 'Null' is not a subtype of type 'DealModel'` exception.
* **Fix & Rationale:** Updated `DealDetailsController` to check for `Get.arguments`. If absent, it reads `Get.parameters['id']`, converts it to an integer, and asynchronously fetches the deal data via `dealRepo.fetchById(id)`. Updated `DealDetailsScreen` with an `Obx` wrapper to display a `CircularProgressIndicator` while the deal loads.
* **Alternatives Considered:** 
  * *Redirecting to Home screen on missing arguments:* Rejected because deep links must land users directly on the target resource to fulfill marketing user journeys.

---

## 2. AI Usage Log

* **Tools Used:** Cursor / ChatGPT / Gemini for code analysis, root-cause diagnosis, and refactoring boilerplate.

### Examples of Incorrect/Misleading AI Suggestions:

1. **RES-106 (Timezone formatting):**
   * *AI Suggestion:* The AI initially suggested adding `.toLocal()` only inside the `label` getter (`DateFormat('HH:mm').format(start.toLocal())`).
   * *How Caught:* Reviewing `isToday` revealed that it would still compare `start.day` (UTC) with `DateTime.now().day` (Local), leaving the "Pickup today" filter broken for morning slots.
   * *Correction:* Applied `.toLocal()` directly when parsing in `PickupWindowModel.fromJson` and updated `isToday` to compare `year`, `month`, and `day` using local time.

2. **RES-107 (Deep link fallback):**
   * *AI Suggestion:* The AI suggested passing a dummy/mock `DealModel` object as a fallback when `Get.arguments` is null to avoid changing `deal` from a sync field to `Rxn<DealModel>`.
   * *How Caught:* A mock object causes flash-of-incorrect-content (FOIC) or displays placeholder pricing to the end user.
   * *Correction:* Converted `deal` into an `Rxn<DealModel>` with an explicit loading state and fetched real deal data asynchronously from `dealRepo.fetchById(id)`.

---

## 3. Design Questions

### Q1: Lifecycle Difference (`GetxController` vs Widget `State`)
* **Difference:** A Widget `State` lifecycle (`initState`, `build`, `dispose`) is strictly bound to the element tree rendered on screen. A `GetxController` lifecycle (`onInit`, `onReady`, `onClose`) is managed by GetX's dependency injection container; its lifetime can extend beyond a widget's unmounting depending on binding memory strategies (`Get.put` vs `Get.lazyPut` vs `autoRemove`).
* **Bug Connection:** **RES-102 / RES-103** (Although not submitted for this test, these bugs exist because stream listeners or network polling inside controllers continue running after the view is disposed).

### Q2: Scope of Reactivity with `Obx`
* Wrapping a large widget subtree in a single `Obx` causes Flutter to mark the entire subtree as dirty whenever any observed `Rx` variable changes. This triggers recursive rebuilds for all child widgets within that tree, destroying scrolling performance and dropping frames.
* **Decision Rule:** Keep `Obx` tightly scoped to the smallest leaf widget that depends on reactive state (e.g., wrapping only a `Text` or `Chip` showing remaining inventory), leaving static containers, layouts, and parent cards outside reactive rebuild scopes.

### Q3: Automated Testing for RES-106
* **Test Strategy:** Write a unit test for `PickupWindowModel.fromJson` that passes UTC ISO-8601 strings (e.g., `'2026-09-24T23:00:00Z'`) and asserts that `.label` and `.isToday` return expected values relative to system local time.
* **Code Changes for Testability:** Refactor `isToday` to accept an optional reference timestamp parameter (e.g., `bool isToday([DateTime? relativeTo])`), defaulting to `DateTime.now()`. This allows tests to inject deterministic `DateTime` instances without relying on real-time system clocks.

---

## 4. Time Spent & Future Work

* **Time Spent:** ~4 hours total. As requested by the guidelines emphasizing "depth over volume" for a Junior position[cite: 1], I focused on correctly diagnosing and fixing core bugs (Concurrency, Memory/Jank, Timezone, Routing) rather than providing superficial patches across all tickets.
* **Next Steps with 1 More Day:**
  1. Complete the remaining Bug Tickets (RES-101, 102, 103).
  2. Implement **F-1 (Live Flash Sale Countdowns)** focusing on ticker-scoped leaf widgets to ensure 60fps scrolling.
  3. Implement **F-2 (Impression Tracking)** using batched analytics.