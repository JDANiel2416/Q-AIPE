from sqlalchemy.ext.declarative import declarative_base

# Esta clase 'Base' será la "madre" de todas tus tablas.
# Si creas una clase User, heredará de aquí: class User(Base): ...
Base = declarative_base()