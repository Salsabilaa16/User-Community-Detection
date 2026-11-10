# User-Community-Detection

## UTS GRAF Kelompok 7 

Firda Zahira Safa (23031554024)
  - Community detection metode Leiden
    
Geonsrina Alsyaifi Salsabila (23031554080)
  - Community detection metode Louvain
    
Mutiara Restu Aulya (23031554113)
  - Collaborative filtering (perhitungan kemiripan, relasi SIMILAR)
  - Sistem rekomendasi film

## Deskripsi Proyek

Proyek ini memodelkan dataset MovieLens sebagai graf
di Neo4j, lalu menggunakannya untuk tiga analisis:
  (1) sistem rekomendasi film dengan collaborative filtering,
  (2) community detection dengan metode Louvain, dan
  (3) community detection dengan metode Leiden.

Model graf:
  (User)-[:RATED {rating, timestamp}]->(Movie)-[:HAS]->(Genre)
  - 610 User, 9.742 Movie, 20 Genre
  - 100.836 relasi RATED, 22.084 relasi HAS

## Alur pengerjaan:
  a. Impor movies.csv dan ratings.csv dengan LOAD CSV.
  
  b. Eksplorasi data: distribusi rating (rata-rata dan median 3,5),
     film terpopuler, dan jumlah film per genre.
     
  c. Collaborative filtering (user-based):
     - "Suka" didefinisikan sebagai rating >= 4.
     - Kemiripan antar user dihitung dengan cosine similarity
       (GDS Node Similarity), diambil 10 tetangga terdekat per user.
     - Hasilnya disimpan sebagai relasi baru
       (User)-[:SIMILAR {score}]->(User), sebanyak 6.090 relasi.
     - Rekomendasi = film yang disukai user-user mirip tetapi belum
       dirating oleh user target, diurutkan dengan
       skor = jumlah dari (kemiripan x rating).
       
  d. Community detection pada graf User-SIMILAR-User
     (tak berarah, berbobot kemiripan):
     - Louvain : modularity 0,5657
     - Leiden  : modularity 0,5745
     Leiden menghasilkan modularity sedikit lebih tinggi, dan komunitasnya
     dijamin terhubung serta dapat direproduksi (randomSeed 42).
  e. Interpretasi komunitas melalui genre khas tiap komunitas (lift).

Seluruh query tersedia di file query_movielens_kelompok7.cypher.

## BATASAN PROYEK

  - Dataset yang digunakan adalah MovieLens. Hanya
    movies.csv dan ratings.csv yang diimpor; links.csv (ID eksternal) dan
    tags.csv (hanya dimiliki 58 dari 610 user) tidak digunakan.
  - Batas "suka" ditetapkan rating >= 4 dan jumlah tetangga top-K = 10.
    Sensitivitas hasil terhadap kedua parameter ini belum diuji.
  - Collaborative filtering yang digunakan hanya user-based; item-based
    tidak dibandingkan.
  - Belum dilakukan evaluasi kuantitatif rekomendasi (misalnya
    precision@K); validasi masih bersifat kualitatif.
  - Rekomendasi cenderung memunculkan film populer (popularity bias) dan
    tidak dapat diberikan untuk user tanpa riwayat rating (cold start).
  - Perbedaan kebiasaan memberi rating antar user belum dinormalisasi.
  - Hasil Louvain bersifat acak sehingga dapat sedikit berbeda setiap kali
    dijalankan.
  - Proyek dijalankan secara lokal di Neo4j Desktop (Cypher 25) dengan
    plugin Graph Data Science.
