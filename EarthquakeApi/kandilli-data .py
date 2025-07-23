import requests
import firebase_admin
from firebase_admin import credentials, firestore
import schedule
import time

print("Başlatılıyor: Firebase bağlantısı kuruluyor...")

cred = credentials.Certificate("C:/Users/fatih/Downloads/deprem-uygulamasi-41624-firebase-adminsdk-fbsvc-877e4bdf00.json")
firebase_admin.initialize_app(cred)
print("Başarılı: Firebase bağlantısı kuruldu.")

db = firestore.client()
url = "https://kandilli.deno.dev/"

def count_documents():
    docs = db.collection('earthquakes').stream()
    doc_count = sum(1 for _ in docs)
    return doc_count

def get_earthquake():
    print("Veri çekiliyor: Kandilli sunucusuna istek atılıyor...")

    try:
        old_count = count_documents()
        print(f"Mevcut kayıt sayısı (önce): {old_count}")

        response = requests.get(url)
        response.raise_for_status()
        print("Başarılı: Kandilli'den veri alındı.")

        earthquake_data = response.json()
        latest_quakes = earthquake_data[:50]

        added_count = 0
        for quake in latest_quakes:
            data = {
                "latitude": float(quake.get("latitude", 0)),
                "longitude": float(quake.get("longitude", 0)),
                "magnitude": float(quake.get("ml", 0)),
                "depth": float(quake.get("depth", 0)),
                "date": quake.get("date"),
                "time": quake.get("time"),
                "location": quake.get("location")
            }
            db.collection('earthquakes').add(data)
            added_count += 1

        print(f"Başarılı: {added_count} yeni deprem verisi eklendi.")

        docs = db.collection('earthquakes').order_by("date").stream()
        docs_list = list(docs)

        if len(docs_list) > 50:
            to_delete = docs_list[:len(docs_list) - 50]
            for doc in to_delete:
                db.collection('earthquakes').document(doc.id).delete()
            print(f"Temizlik: {len(to_delete)} eski kayıt silindi.")
        else:
            print("Temizlik gerekmedi: Kayıt sayısı zaten 50 veya daha az.")

        new_count = count_documents()
        print(f"Mevcut kayıt sayısı (sonra): {new_count}\n")

    except requests.exceptions.RequestException as e:
        print(f"HATA: Veri alınamadı. {e}\n")

def fetch_data_periodically():
    print("Başlatılıyor: Her 10 dakikada bir veri çekme planlandı.")
    schedule.every(10).minutes.do(get_earthquake)

    print("İlk veri çekme işlemi yapılıyor...")
    get_earthquake()

    while True:
        schedule.run_pending()
        time.sleep(1)

if __name__ == '__main__':
    fetch_data_periodically()
