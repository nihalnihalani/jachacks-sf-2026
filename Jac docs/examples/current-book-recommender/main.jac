node User {
    has name: str;
    has interests: list[str];
}

node Book {
    has title: str;
    has genre: str;
}

edge Candidate {}

def recommend_books(
    interests: list[str],
    available_books: list[dict]
) -> list[str] by llm();

sem recommend_books = """
Select up to three books that best match the reader's interests.
Return only exact titles present in available_books. Never invent a title.
""";

walker RecommendBooks {
    has reports: list[list[str]] = [];

    can inspect_user with User entry {
        books: list[Book] = [->:Candidate:->];
        catalog = [
            {"title": book.title, "genre": book.genre}
            for book in books
        ];
        recommendations = recommend_books(here.interests, catalog);
        report recommendations;
    }
}

with entry {
    user = User(
        name="Alex",
        interests=["AI", "Python", "Space"]
    );

    book1 = Book(
        title="The Jac Programming Language",
        genre="Technology"
    );
    book2 = Book(
        title="A Brief History of Time",
        genre="Science"
    );
    book3 = Book(
        title="Pride and Prejudice",
        genre="Classic Fiction"
    );

    user +>: Candidate :+> [book1, book2, book3];

    result = user spawn RecommendBooks();
    print(f"Recommendations for {user.name}: {result.reports[0]}");
}
