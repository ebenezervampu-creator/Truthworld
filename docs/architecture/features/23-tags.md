# Feature 23: Tags

## Overview
The **Tags** feature is an architectural module designed to handle semantic categorization, complementing the Hashtag and Category systems. It is primarily used during video upload and editing to enhance SEO and discoverability.

## Architecture
- **Location**: `lib/features/tags/`
- **Role**: Acts as a centralized schema definition for allowed ecosystem tags. It provides the UI components (like `tags_input_field.dart` seen in the Video feature) the necessary validation logic to ensure creators do not exceed tag limits (e.g., max 15 tags) or use blacklisted terms.
