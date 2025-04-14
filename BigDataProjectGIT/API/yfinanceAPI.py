import yfinance as yf
from pymongo import MongoClient

# Define ticker and date range
ticker_symbol = "NVDA"
start_date = "2025-03-31"
end_date = "2025-04-09"

# Download data with 15-minute intervals
data = yf.download(
    tickers=ticker_symbol,
    start=start_date,
    end=end_date,
    interval="5m",
    prepost=True,   
    progress=False
)

# Reset index (date becomes a column)
data.reset_index(inplace=True)

# Rename columns
data.columns = ["Date", "Open", "High", "Low", "Close", "Volume"]

# Print to confirm new column names

# Connect to MongoDB
client = MongoClient("ongoDB Connection String")
db = client["stock_data"]
collection = db["nvda_trends"]

# Insert into MongoDB
inserted = 0
for _, row in data.iterrows():
    doc = {
        "Date": row["Date"],
        "Open": float(row["Open"]),
        "High": float(row["High"]),
        "Low": float(row["Low"]),
        "Close": float(row["Close"]),
        "Volume": int(row["Volume"])
    }
    try:
        collection.insert_one(doc)
        inserted += 1
    except Exception as e:
        print(f"Error inserting row: {e}")

print(f"{inserted} records inserted.")