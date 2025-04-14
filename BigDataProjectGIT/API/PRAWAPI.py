import praw
import pymongo
import datetime as dt
import re
import time

# Reddit API setup
reddit = praw.Reddit(
    client_id="Reddit API Client ID",
    client_secret="Reddit API Client Secret",
    user_agent="Name of your application"
)

# MongoDB setup
client = pymongo.MongoClient("MongoDB Connection String")
db = client["NVIDIA"]
collection = db["Stock_Sentiment"]

# Subreddits and keywords
subreddits = ['stocks', 'investing', 'StockMarket', 'wallstreetbets', 'nvidia', 'AMD_Stock']
keywords = ['NVDA', 'NVIDIA', 'nvidia stock']

def extract_tickers(text):
    return re.findall(r'\b[A-Z]{1,5}\b', text)

post_count = 0
print("Collecting data from specified subreddits...")
for subreddit_name in subreddits:
    try:
        subreddit = reddit.subreddit(subreddit_name)
        for post in subreddit.search(query=" OR ".join(keywords), sort="new", limit=200):
            try:
                if not collection.find_one({"id": post.id}):
                    tickers = extract_tickers(post.title + " " + post.selftext)
                    post_data = {
                        "id": post.id,
                        "tickers": tickers,
                        "subreddit": subreddit_name,
                        "author": str(post.author),
                        "title": post.title,
                        "text": post.selftext,
                        "date": dt.datetime.fromtimestamp(post.created_utc).strftime("%Y-%m-%d"),
                    }
                    collection.insert_one(post_data)
                    post_count += 1
                    print(dt.datetime.fromtimestamp(post.created_utc).strftime("%Y-%m-%d"))
                time.sleep(1)  
            except Exception as e:
                print(f"Error processing post {post.id}: {e}")
    except Exception as e:
        print(f"Error with subreddit {subreddit_name}: {e}")

print(f"Collected {post_count} new posts.")
print("Data written to MongoDB.")