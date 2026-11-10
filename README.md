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

Proyek ini memodelkan data rating film MovieLens sebagai graf di Neo4j,
lalu memanfaatkan struktur graf tersebut untuk tiga tujuan:

  1) Sistem rekomendasi film menggunakan collaborative filtering
  2) Community detection menggunakan metode Louvain
  3) Community detection menggunakan metode Leiden

Ketiga analisis saling terhubung. Kemiripan selera antar user yang
dihitung untuk sistem rekomendasi disimpan sebagai relasi SIMILAR, lalu
jaringan User-SIMILAR-User tersebut digunakan sebagai dasar community
detection untuk menemukan kelompok user dengan selera film yang serupa.


## DATASET

Sumber : MovieLens, GroupLens Research (https://grouplens.org/datasets/movielens/)

File yang digunakan:
  movies.csv   movieId, title, genres (dipisahkan "|")   9.742 film
  ratings.csv  userId, movieId, rating, timestamp        100.836 rating

Karakteristik data:
  - 610 user, setiap user memiliki minimal 20 rating
  - Skala rating 0,5 - 5,0 (kelipatan 0,5)
  - Rata-rata dan median rating: 3,5
  - 20 genre, termasuk kategori "(no genres listed)"

File yang tidak digunakan:
  links.csv    Hanya berisi ID eksternal (IMDb dan TMDb)
  tags.csv     Hanya dimiliki 58 dari 610 user (sekitar 10%)


## TOOLS DAN TEKNOLOGI

  - Neo4j Desktop 2.x (instance lokal)
  - Cypher 25
  - Neo4j Graph Data Science (GDS) Library
    
      gds.nodeSimilarity  : perhitungan kemiripan antar user
    
      gds.louvain         : community detection metode Louvain
    
      gds.leiden          : community detection metode Leiden
    
  - Python 
  
      Pandas : Pengolahan dan manipulasi data.

      NetworkX : Analisis struktur jaringan graf.

      PyVis : Membuat visualisasi graf interaktif dalam format HTML.

## MODEL GRAF

Node:
  User    userId               610 node
  Movie   movieId, title       9.742 node
  Genre   genre                20 node

Relasi:
  (User)-[:RATED {rating, timestamp}]->(Movie)    100.836 relasi
  (Movie)-[:HAS]->(Genre)                          22.084 relasi
  (User)-[:SIMILAR {score}]->(User)                 6.090 relasi *

  * Relasi SIMILAR tidak berasal dari dataset, melainkan hasil
    perhitungan cosine similarity (lihat bagian 6).

Constraint unik: Movie.movieId, User.userId, Genre.genre


## CARA MENJALANKAN

Persiapan:
  1) Install Neo4j Desktop, lalu buat instance dan database baru.
  2) Install plugin Graph Data Science pada instance tersebut, lalu
     restart instance. Cek dengan: RETURN gds.version()
  3) Salin movies.csv dan ratings.csv ke folder "import" milik instance.

Urutan eksekusi:
  I-1 s.d. I-3  Constraint dan impor data
  01 s.d. 06    Eksplorasi data
  07 s.d. 11    Collaborative filtering dan rekomendasi
  12 s.d. 18    Community detection (Louvain dan Leiden)

Perhatian:
  - Jalankan satu query per eksekusi, sesuai urutan.
  - Query I-3 (impor rating) dan 08 (pembuatan relasi SIMILAR) hanya
    boleh dijalankan SEKALI, karena menggunakan CREATE / mode write
    sehingga relasi akan terduplikasi bila diulang.
  - Graf proyeksi GDS ("liked" dan "similar") hanya tersimpan di memori
    dan hilang setelah instance di-restart. Jalankan ulang query
    proyeksi (07 dan 12) bila diperlukan.
  - Untuk demonstrasi tanpa mengubah database, algoritma GDS dapat
    dijalankan dalam mode .stats (contoh: gds.nodeSimilarity.stats).


## METODOLOGI

Collaborative Filtering (user-based)
  1) Rating >= 4 dianggap "suka" (rata-rata rating adalah 3,5).
  2) Kemiripan antar user dihitung dengan cosine similarity berdasarkan
     film yang sama-sama disukai. Setiap user dihubungkan ke 10 user
     paling mirip melalui relasi SIMILAR.
  3) Rekomendasi untuk user target berupa film yang disukai user-user
     mirip tetapi belum dirating oleh target, diurutkan berdasarkan
     skor = jumlah dari (kemiripan x rating).

Community Detection
  1) Graf User-SIMILAR-User diproyeksikan sebagai graf tak berarah
     dengan bobot kemiripan.
  2) Louvain dan Leiden dijalankan untuk mengelompokkan user, lalu
     hasilnya dibandingkan berdasarkan modularity.


## HASIL
### Kemiripan antar user (cosine, topK = 10)
  User yang dibandingkan      : 609
  Relasi SIMILAR terbentuk    : 6.090
  Rata-rata kemiripan         : 0,275
  Kemiripan tertinggi         : 0,681

### Contoh rekomendasi untuk user 1
  No  Film                              Skor     Disukai oleh user mirip
  1   Terminator 2: Judgment Day (1991) 13,195   10 dari 10
  2   Aliens (1986)                     12,578    9 dari 10
  3   Breakfast Club, The (1985)        11,827    9 dari 10
  4   Stand by Me (1986)                11,228    8 dari 10
  5   Die Hard (1988)                   11,074    9 dari 10

  Rekomendasi didominasi film populer era 1980-1990an, konsisten dengan
  pola selera user 1 dan user-user yang mirip dengannya.

### Community detection
  Metode    Modularity
  - Louvain   0,5657
  - Leiden    0,5745

  Kedua metode menghasilkan struktur komunitas yang jelas (modularity berada pada rentang 0,3 - 0,7). Leiden memberikan modularity sedikit lebih tinggi, komunitas yang dijamin terhubung, serta hasil yang dapat direproduksi, sehingga digunakan sebagai hasil utama.

  Visualisasi graf dibuat menggunakan Python dan PyVis dalam format HTML interaktif. File tersedia di repository dan dapat diunduh untuk dibuka langsung melalui browser.
  - Louvain : visualisasi_louvain.html
  - Leiden : visualisasi_leiden.html

## BATASAN PROYEK

  - Hanya movies.csv dan ratings.csv yang digunakan; tags.csv dan
    links.csv tidak dimanfaatkan.
  - Parameter batas "suka" (rating >= 4) dan jumlah tetangga (topK = 10)
    ditetapkan tanpa uji sensitivitas.
  - Collaborative filtering yang diterapkan hanya user-based; pendekatan
    item-based tidak dibandingkan.
  - Belum dilakukan evaluasi kuantitatif rekomendasi (misalnya
    precision@K atau hit rate); validasi masih bersifat kualitatif.
  - Rekomendasi cenderung memunculkan film populer (popularity bias).
  - Rekomendasi tidak dapat diberikan untuk user tanpa riwayat rating
    (cold start).
  - Perbedaan kebiasaan memberi rating antar user belum dinormalisasi.
  - Hasil Louvain bersifat acak sehingga dapat sedikit berbeda setiap
    kali dijalankan.
  - Seluruh analisis dijalankan pada instance Neo4j lokal.
