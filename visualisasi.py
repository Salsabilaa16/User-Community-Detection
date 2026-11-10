
import pandas as pd
import networkx as nx
from pyvis.network import Network

# ==========================================
# 1. MEMBACA DATA CSV
# ==========================================

users = pd.read_csv("D://TA//Louvain//user.csv")
edges = pd.read_csv("D://TA//Louvain//edges.csv")

# ==========================================
# 2. MEMBERSIHKAN DATA KOSONG
# ==========================================

users = users.dropna(
    subset=["userId", "komunitas"]
).copy()

edges = edges.dropna(
    subset=["source", "target", "komunitas"]
).copy()

# ==========================================
# 3. MENYAMAKAN TIPE DATA
# ==========================================

# ID User menjadi string
users["userId"] = users["userId"].astype(str)
edges["source"] = edges["source"].astype(str)
edges["target"] = edges["target"].astype(str)

# Komunitas menjadi integer lalu string
users["komunitas"] = (
    pd.to_numeric(users["komunitas"], errors="raise")
    .astype(int)
    .astype(str)
)

edges["komunitas"] = (
    pd.to_numeric(edges["komunitas"], errors="raise")
    .astype(int)
    .astype(str)
)

# Jumlah relasi menjadi integer
users["jumlahRelasi"] = pd.to_numeric(
    users["jumlahRelasi"], errors="coerce"
).fillna(0).astype(int)

# Score menjadi angka desimal
edges["score"] = pd.to_numeric(
    edges["score"], errors="coerce"
).fillna(0)

# ==========================================
# 4. MEMBUAT GRAF
# ==========================================

G = nx.Graph()

# ==========================================
# 5. MENAMBAHKAN NODE USER
# ==========================================

for _, row in users.iterrows():

    G.add_node(
        row["userId"],
        komunitas=row["komunitas"],
        jumlahRelasi=int(row["jumlahRelasi"])
    )

# ==========================================
# 6. MENAMBAHKAN RELASI INTERNAL KOMUNITAS
# ==========================================

komunitas_user = dict(
    zip(users["userId"], users["komunitas"])
)

for _, row in edges.iterrows():

    source = row["source"]
    target = row["target"]

    if source in G and target in G:

        if komunitas_user[source] == komunitas_user[target]:

            G.add_edge(
                source,
                target,
                score=row["score"]
            )

# ==========================================
# 7. WARNA BERDASARKAN KOMUNITAS
# ==========================================

komunitas_list = sorted(
    users["komunitas"].unique(),
    key=int
)

palette = [
    "#DC4E4E",
    "#4D96FF",
    "#B983FF",
    "#FF8E3C",
    "#8AE9BD",
    "#E79AB0"
]

warna_komunitas = {
    komunitas: palette[i % len(palette)]
    for i, komunitas in enumerate(komunitas_list)
}

# ==========================================
# 8. MEMBUAT VISUALISASI PYVIS
# ==========================================

net = Network(
    height="800px",
    width="100%",
    bgcolor="#FFFFFF",
    font_color="black",
    notebook=False
)

# ==========================================
# 9. UKURAN NODE BERDASARKAN JUMLAH RELASI
# ==========================================

min_relasi = users["jumlahRelasi"].min()
max_relasi = users["jumlahRelasi"].max()

for node, data in G.nodes(data=True):

    jumlah = data["jumlahRelasi"]

    if max_relasi == min_relasi:
        ukuran = 20
    else:
        ukuran = 10 + (
            (jumlah - min_relasi) /
            (max_relasi - min_relasi)
        ) * 60

    komunitas = data["komunitas"]

    net.add_node(
        node,
        label=node,
        size=ukuran,
        color=warna_komunitas[komunitas],
        title=(
            f"User ID: {node}\n"
            f"Komunitas: {komunitas}\n"
            f"Jumlah Koneksi Internal: {jumlah}"
        )
    )

# ==========================================
# 10. MENAMBAHKAN GARIS RELASI
# ==========================================

for source, target, data in G.edges(data=True):

    net.add_edge(
        source,
        target,
        title=f"Similarity Score: {data['score']:.4f}"
    )

# ==========================================
# 11. PENGATURAN TAMPILAN GRAF
# ==========================================

net.set_options("""
{
  "nodes": {
    "shape": "dot",
    "borderWidth": 1,
    "font": {
      "size": 12
    }
  },
  "edges": {
    "smooth": {
      "type": "continuous"
    },
    "color": {
      "inherit": false,
      "color": "#BDBDBD"
    }
  },
  "physics": {
    "enabled": true,
    "barnesHut": {
      "gravitationalConstant": -3000,
      "centralGravity": 0.3,
      "springLength": 120,
      "springConstant": 0.04,
      "damping": 0.09
    },
    "stabilization": {
      "iterations": 200
    }
  },
  "interaction": {
    "hover": true,
    "tooltipDelay": 100,
    "navigationButtons": true,
    "keyboard": true
  }
}
""")

# ==========================================
# 12. MENYIMPAN VISUALISASI
# ==========================================

net.write_html("visualisasi_louvain.html")

# ==========================================
# 13. INFORMASI HASIL
# ==========================================

print("Visualisasi berhasil dibuat!")
print("Jumlah node:", G.number_of_nodes())
print("Jumlah relasi unik:", G.number_of_edges())

print("\n20 User dengan koneksi internal terbanyak:")

for node, data in sorted(
    G.nodes(data=True),
    key=lambda x: x[1]["jumlahRelasi"],
    reverse=True
)[:20]:

    print(
        "User:", node,
        "| Komunitas:", data["komunitas"],
        "| Jumlah Koneksi:", data["jumlahRelasi"]
    )

print("\nDaftar komunitas:", komunitas_list)

print("\nFile berhasil disimpan:")
print("visualisasi_louvain.html")
