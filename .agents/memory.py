import os
import uuid
from chromadb import PersistentClient

# Ensure the memory directory exists
memory_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "memory"))
os.makedirs(memory_dir, exist_ok=True)

client = PersistentClient(path=memory_dir)
collection = client.get_or_create_collection(name="session_memory")

def add(entry: str, metadata: dict | None = None) -> None:
    """Add a document to the memory store.
    Args:
        entry: The text to store.
        metadata: Optional dict of metadata (e.g., {'type': 'module_plan'}).
    """
    doc_id = str(uuid.uuid4())
    collection.add(ids=[doc_id], documents=[entry], metadatas=[metadata or {}])

def query(text: str, n: int = 5) -> list[str]:
    """Retrieve the *n* most similar documents to *text*.
    Returns a list of document strings.
    """
    results = collection.query(query_texts=[text], n_results=n)
    return results.get("documents", [[]])[0]

# Example usage (can be removed in production)
if __name__ == "__main__":
    add("Sample module plan entry", {"type": "module_plan"})
    print(query("module plan"))
