from fastapi import FastAPI
from pydantic import BaseModel
from sentence_transformers import SentenceTransformer

app = FastAPI()
model = SentenceTransformer("all-MiniLM-L6-v2")


class EmbedRequest(BaseModel):
    text: str


class EmbedBatchRequest(BaseModel):
    texts: list[str]


@app.post("/embed")
def embed(req: EmbedRequest):
    vector = model.encode(req.text).tolist()
    return {"embedding": vector}


@app.post("/embed/batch")
def embed_batch(req: EmbedBatchRequest):
    vectors = model.encode(req.texts).tolist()
    return {"embeddings": vectors}


@app.get("/health")
def health():
    return {"status": "ok"}
