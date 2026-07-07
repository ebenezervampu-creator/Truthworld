# Cloud Function: comments.ts

**Location:** `functions/src/community/comments.ts`

## 📖 What it does & How it works
💬 ADD COMMENT (Callable - Flat Collection)
 Records a comment with the author's trust snapshot for weighted ranking.

## ⚙️ Exports / Primary Functions
- **addComment**
- **getComments**
- **addCommentNested**
- **addReplyNested**
- **toggleCommentInteraction**
- **toggleReplyInteraction**
- **deleteCommentNested**
- **deleteReplyNested**
- **reportCommentNested**

## 🔗 Dependencies (What it depends on to work)
- 📦 **External Package**: `firebase-admin`
- 📦 **External Package**: `firebase-functions/v2/https`
- 📦 **External Package**: `firebase-functions/v2`
- 🔄 **Internal Dependency**: `./types`
