# image caching implementation
*three-tier cache architecture for efficient image storage and display*

## The Problem

Compressed image files (JPG/PNG) are small, but when decoded for display they expand dramatically in memory. A 2MB compressed image can become 48MB+ as raw pixels. With limited cache space, we could only hold a few decoded images, causing constant reloading.

## Three-Tier Solution

We use three separate caches with different purposes:

### 1. Raw Data Cache
- Stores compressed image bytes as downloaded from server
- Large capacity (500 MB) - can hold 100+ full images compressed
- Key: image URL
- This is our "source of truth" - once an image is here, we never need to download it again

### 2. Thumbnail Cache
- Stores pre-decoded small thumbnails for compact post view (80×80)
- Moderate capacity (20 MB) - holds 400+ thumbnails
- Key: image URL + ":thumb"
- These stay in memory because they're tiny (~50KB each decoded)

### 3. Full Image Cache
- Stores recently-decoded full-size images
- Limited capacity (100 MB) - holds 2-5 recent full images
- Key: image URL
- Uses LRU eviction - when full, oldest images are removed
- Not a problem because we can quickly re-decode from raw data cache

## Flow

**On Post Load:**
1. Download compressed image from server (if not already cached)
2. Store in Raw Data Cache
3. Decode to thumbnail size (80×80)
4. Store thumbnail in Thumbnail Cache
5. Display thumbnail in compact view

**On Post Expand:**
1. Check Full Image Cache - if present, display instantly
2. If not present, decode from Raw Data Cache (fast: ~10-30ms)
3. Store in Full Image Cache for next time
4. Display full image

**On Scroll:**
- Thumbnails stay in memory (they're tiny)
- Full images may be evicted from cache (okay, we can re-decode quickly)
- Raw data stays cached (holds 100+ images)

## Key Functions

**downloadAndCache(url) → rawData**
- Downloads image data from server
- Stores in raw data cache
- Returns the compressed data

**getThumbnail(url) → thumbnailImage**
- Check thumbnail cache, return if found
- Otherwise, get raw data from raw cache
- Decode and resize to 80×80
- Store in thumbnail cache
- Return thumbnail

**getFullImage(url) → fullImage**
- Check full image cache, return if found
- Otherwise, get raw data from raw cache
- Decode to full size
- Store in full image cache (may evict old entries)
- Return full image

**preloadImages(urls) → void**
- For each URL not already in raw cache:
  - Download raw data in background
  - Generate thumbnail immediately
  - Cache both
- Don't pre-decode full images (waste of memory until needed)
