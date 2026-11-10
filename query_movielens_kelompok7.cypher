// =====================================================================
// PROYEK MOVIELENS DI NEO4J — Kelompok 7
// Instance : UTS GSD 2023C Kelompok 7
// Database : movie (Cypher 25) · Plugin: Graph Data Science (GDS)
//
// Cara pakai: salin dan jalankan SATU blok per run di Neo4j Query.
// Baris komentar pertama tiap blok = judul query.
//
// STATUS
//   [SUDAH]  Impor, Bagian A (01–06), Bagian B (07–11)
//   [BELUM]  Bagian C (12–18)
//
// PERHATIAN
//   - Query yang MENULIS ke database (jangan dijalankan dua kali):
//     impor ratings, 08, 13, 14
//   - Graf GDS ('liked', 'similar') hanya ada di memori dan hilang
//     setelah instance di-restart. Relasi SIMILAR tetap tersimpan.
// =====================================================================


// ---------------------------------------------------------------------
// IMPOR DATA [SUDAH]
// File movies.csv dan ratings.csv diletakkan di folder import instance
// ---------------------------------------------------------------------

// I-1 · Constraint
CREATE CONSTRAINT movie_id IF NOT EXISTS FOR (m:Movie) REQUIRE m.movieId IS UNIQUE;
CREATE CONSTRAINT genre_name IF NOT EXISTS FOR (g:Genre) REQUIRE g.genre IS UNIQUE;
CREATE CONSTRAINT user_id IF NOT EXISTS FOR (u:User) REQUIRE u.userId IS UNIQUE;


// I-2 · Impor film dan genre
LOAD CSV WITH HEADERS FROM 'file:///movies.csv' AS row
CALL (row) {
  MERGE (m:Movie {movieId: toInteger(row.movieId)})
  SET m.title = row.title
  WITH m, row
  UNWIND split(row.genres, '|') AS genre
  MERGE (g:Genre {genre: genre})
  MERGE (m)-[:HAS]->(g)
} IN TRANSACTIONS OF 1000 ROWS;


// I-3 · Impor user dan rating (JANGAN dijalankan dua kali)
LOAD CSV WITH HEADERS FROM 'file:///ratings.csv' AS row
CALL (row) {
  MATCH (m:Movie {movieId: toInteger(row.movieId)})
  MERGE (u:User {userId: toInteger(row.userId)})
  CREATE (u)-[:RATED {rating: toFloat(row.rating), timestamp: toInteger(row.timestamp)}]->(m)
} IN TRANSACTIONS OF 5000 ROWS;


// ---------------------------------------------------------------------
// BAGIAN A · MENGENAL DATA [SUDAH]
// ---------------------------------------------------------------------

// 01 · Isi database: jumlah node per label
MATCH (n)
RETURN labels(n)[0] AS jenisNode, count(*) AS jumlah
ORDER BY jumlah DESC


// 02 · Isi database: jumlah relasi per tipe
MATCH ()-[r]->()
RETURN type(r) AS jenisRelasi, count(*) AS jumlah


// 03 · Struktur graf: contoh satu user, film yang dirating, dan genrenya
MATCH p = (u:User {userId: 1})-[:RATED]->(:Movie)-[:HAS]->(:Genre)
RETURN p
LIMIT 25


// 04 · Distribusi nilai rating
MATCH ()-[r:RATED]->()
RETURN r.rating AS rating, count(*) AS jumlah
ORDER BY rating


// 04b · Rata-rata dan median rating
MATCH ()-[r:RATED]->()
RETURN round(avg(r.rating), 2) AS rataRata,
       percentileCont(r.rating, 0.5) AS median,
       round(100.0 * sum(CASE WHEN r.rating >= 4 THEN 1 ELSE 0 END) / count(r), 1) AS persenSuka_ge4,
       round(100.0 * sum(CASE WHEN r.rating >= 3.5 THEN 1 ELSE 0 END) / count(r), 1) AS persen_ge3_5


// 04c · Kebiasaan memberi rating per user
MATCH (u:User)-[r:RATED]->()
WITH u, avg(r.rating) AS rataUser
RETURN round(min(rataUser), 2) AS userPalingPelit,
       round(percentileCont(rataUser, 0.5), 2) AS medianRataUser,
       round(max(rataUser), 2) AS userPalingMurah


// 05 · 10 film yang paling banyak dirating
MATCH (:User)-[r:RATED]->(m:Movie)
RETURN m.title AS film, count(r) AS jumlahRating, round(avg(r.rating), 2) AS rataRata
ORDER BY jumlahRating DESC
LIMIT 10


// 06 · Jumlah film per genre
MATCH (m:Movie)-[:HAS]->(g:Genre)
RETURN g.genre AS genre, count(m) AS jumlahFilm
ORDER BY jumlahFilm DESC


// ---------------------------------------------------------------------
// BAGIAN B · COLLABORATIVE FILTERING, user-based [SUDAH]
// "Suka" = rating >= 4 · kemiripan = cosine similarity, top-10 tetangga
// ---------------------------------------------------------------------

// Cek plugin GDS terpasang
RETURN gds.version()


// 07 · Proyeksi graf User–LIKED–Movie ke memori GDS
MATCH (u:User)-[r:RATED]->(m:Movie)
WHERE r.rating >= 4.0
WITH gds.graph.project('liked', u, m, {
  sourceNodeLabels: 'User',
  targetNodeLabels: 'Movie',
  relationshipType: 'LIKED'
}) AS g
RETURN g.graphName AS graf, g.nodeCount AS jumlahNode, g.relationshipCount AS jumlahRelasi


// 08 · Hitung kemiripan antar user (Cosine, 10 tetangga terdekat) — JANGAN dijalankan dua kali
CALL gds.nodeSimilarity.write('liked', {
  similarityMetric: 'COSINE',
  topK: 10,
  writeRelationshipType: 'SIMILAR',
  writeProperty: 'score'
})
YIELD nodesCompared, relationshipsWritten, similarityDistribution
RETURN nodesCompared AS userDibandingkan,
       relationshipsWritten AS relasiSimilarDibuat,
       round(similarityDistribution.mean, 3) AS rataRataKemiripan,
       round(similarityDistribution.max, 3) AS kemiripanTertinggi


// 09 · User yang paling mirip dengan user 1
WITH 1 AS target
MATCH (u:User {userId: target})-[s:SIMILAR]->(v:User)
RETURN v.userId AS userMirip, round(s.score, 3) AS kemiripan
ORDER BY kemiripan DESC


// 10 · Bukti kemiripan: film yang sama-sama disukai user 1 dan user paling miripnya
WITH 1 AS target
MATCH (u:User {userId: target})-[s:SIMILAR]->(v:User)
WITH u, v, s ORDER BY s.score DESC LIMIT 1
MATCH p = (u)-[r1:RATED]->(m:Movie)<-[r2:RATED]-(v)
WHERE r1.rating >= 4 AND r2.rating >= 4
RETURN p
LIMIT 30


// 11 · Rekomendasi 10 film untuk user 1
// (garis kuning "(:Movie) has no incoming [:RATED]" adalah peringatan keliru dari editor, abaikan)
WITH 1 AS target
MATCH (u:User {userId: target})-[s:SIMILAR]->(v:User)-[r:RATED]->(m:Movie)
WHERE r.rating >= 4 AND NOT EXISTS { (u)-[:RATED]->(m) }
RETURN m.title AS filmRekomendasi,
       round(sum(s.score * r.rating), 3) AS skor,
       count(DISTINCT v) AS disukaiOlehUserMirip
ORDER BY skor DESC
LIMIT 10

// 12 . Proyeksi Graf User Community

MATCH (u:User)-[s:SIMILAR]->(v:User)
WITH gds.graph.project(
  'userCommunity',
  u,
  v,
  {
    sourceNodeLabels: 'User',
    targetNodeLabels: 'User',
    relationshipType: 'SIMILAR',
    relationshipProperties: s { .score }
  }
) AS g
RETURN g.graphName AS namaGraf,
       g.nodeCount AS jumlahNode,
       g.relationshipCount AS jumlahRelasi

// 13 . Deteksi Komunitas dengan Algoritma Louvain

CALL gds.louvain.write('userCommunity', {
  relationshipWeightProperty: 'score',
  writeProperty: 'louvainCommunity'
})
YIELD communityCount,
      modularity,
      nodePropertiesWritten
RETURN communityCount AS jumlahKomunitas,
       round(modularity, 4) AS modularitas,
       nodePropertiesWritten AS nodeDiperbarui

// 14 . Menghitung Jumlah Pengguna per Komunitas

MATCH (u:User)
WHERE u.louvainCommunity IS NOT NULL
RETURN u.louvainCommunity AS komunitas,
       count(u) AS jumlahPengguna
ORDER BY komunitas ASC

// 15 . Menampilkan Hasil Pengelompokan Komunitas

MATCH (u:User)
WHERE u.louvainCommunity IS NOT NULL
RETURN u.userId AS userId,
       u.louvainCommunity AS komunitas
LIMIT 20

// 16 . Menampilkan Data Pengguna dan Komunitas

MATCH (u:User)-[s:SIMILAR]-(v:User)
WHERE u.louvainCommunity = v.louvainCommunity
WITH u, u.louvainCommunity AS komunitas,
     count(DISTINCT v) AS jumlahKoneksi,
     sum(s.score) AS totalBobot
ORDER BY komunitas, jumlahKoneksi DESC, totalBobot DESC
WITH komunitas,
     collect({
       userId: u.userId,
       jumlahKoneksi: jumlahKoneksi,
       totalBobot: totalBobot
     })[0] AS pusat
RETURN komunitas,
       pusat.userId AS userPusat,
       pusat.jumlahKoneksi AS jumlahKoneksi,
       round(pusat.totalBobot, 4) AS totalBobot
ORDER BY komunitas

// 17 . Menghitung Jumlah Relasi Setiap Pengguna (lalu hasilnya simpan ke user.csv)

MATCH (u:User)
OPTIONAL MATCH (u)-[s:SIMILAR]-(v:User)
WHERE u.louvainCommunity = v.louvainCommunity

RETURN
    u.userId AS userId,
    u.louvainCommunity AS komunitas,
    COUNT(DISTINCT v) AS jumlahRelasi

ORDER BY komunitas, jumlahRelasi DESC

// 18 . Data Relasi Antar Pengguna (lalu hasil nya simpan ke edges.csv)

MATCH (u:User)-[s:SIMILAR]->(v:User)
WHERE u.louvainCommunity = v.louvainCommunity

RETURN
    u.userId AS source,
    v.userId AS target,
    s.score AS score,
    u.louvainCommunity AS komunitas

ORDER BY komunitas

// 19 . Membuat Graph User Community2

MATCH (u:User)-[s:SIMILAR]->(v:User)
WITH gds.graph.project(
  'userCommunity2',
  u,
  v,
  {
    sourceNodeLabels: 'User',
    targetNodeLabels: 'User',
    relationshipType: 'SIMILAR',
    relationshipProperties: s { .score }
  }
) AS g
RETURN g.graphName AS namaGraf,
       g.nodeCount AS jumlahNode,
       g.relationshipCount AS jumlahRelasi


// 20 . Menjalankan Algoritma Leiden

CALL gds.leiden.write('userCommunity2', {
  relationshipWeightProperty: 'score',
  writeProperty: 'leidenCommunity'
})
YIELD communityCount,
      modularity,
      nodePropertiesWritten
RETURN communityCount AS jumlahKomunitas,
       round(modularity, 4) AS modularitas,
       nodePropertiesWritten AS nodeDiperbarui


// 21 . Menghitung Jumlah User per Komunitas

MATCH (u:User)
WHERE u.leidenCommunity IS NOT NULL
RETURN u.leidenCommunity AS komunitas,
       count(u) AS jumlahPengguna
ORDER BY komunitas ASC


// 22 . Menampilkan 20 User Pertama
MATCH (u:User)
WHERE u.leidenCommunity IS NOT NULL
RETURN u.userId AS userId,
       u.leidenCommunity AS komunitas
LIMIT 20


// 23 . Visualisasi Relasi Antar-User dalam Komunitas

MATCH (u:User)-[s:SIMILAR]->(v:User)
WHERE u.leidenCommunity = v.leidenCommunity
RETURN u, s, v


// 24 . Menampilkan Detail Relasi SIMILAR dalam Komunitas

MATCH (u:User)-[s:SIMILAR]->(v:User)
WHERE u.leidenCommunity = v.leidenCommunity
RETURN
    u.userId AS source,
    v.userId AS target,
    s.score AS score,
    u.leidenCommunity AS komunitas
ORDER BY komunitas

