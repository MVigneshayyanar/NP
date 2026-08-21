import urllib.request
import urllib.error

def fetch(url):
    print(f"Fetching {url}...")
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req) as response:
            print(f"Status: {response.status}")
            print(f"Body: {response.read().decode('utf-8')}")
    except urllib.error.HTTPError as e:
        print(f"Status: {e.code}")
        print(f"Body: {e.read().decode('utf-8')}")
    except Exception as e:
        print(f"Error: {e}")

fetch("http://localhost:3000/internal/dashboard/floor-plans/")
fetch("http://localhost:8000/internal/dashboard/floor-plans/")
