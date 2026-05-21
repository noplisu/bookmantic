export interface Book {
  id: number;
  title: string;
  url: string;
  description: string;
  genres: string | null;
  category: string | null;
  created_at: string;
  updated_at: string;
  embedding_ready: boolean;
  cosine_distance?: number;
  cosine_similarity?: number;
}

export interface ApiErrorBody {
  error?: string;
  errors?: string[];
}
