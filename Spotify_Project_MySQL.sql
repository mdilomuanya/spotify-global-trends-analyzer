-- Drop everything to avoid conflicts on rebuild --
DROP TABLE IF EXISTS spotify_enriched;
DROP TABLE IF EXISTS genre_popularity_by_country;
DROP TABLE IF EXISTS genre_popularity_by_continent;
DROP TABLE IF EXISTS global_artists_exports;
DROP TABLE IF EXISTS artist_country_streams;
DROP TABLE IF EXISTS regional_superstars;
DROP TEMPORARY TABLE IF EXISTS ranked_local_artists;


-- Creating the Table and Loading in Data--
DROP TABLE IF EXISTS spotify_enriched;
CREATE TABLE spotify_enriched (
  current_rank INT,
  uri VARCHAR(100),
  artist_names VARCHAR(255),
  track_name VARCHAR(255),
  track_source VARCHAR(100),
  peak_rank INT,
  previous_rank INT,
  weeks_on_chart INT,
  streams BIGINT,
  country VARCHAR(100),
  track_id VARCHAR(100),
  main_artist VARCHAR(255),
  artist_genres TEXT,
  artist_popularity INT
);


-- 1 Creating the table for genre popularity by country--
DROP TABLE IF EXISTS genre_popularity_by_country;
CREATE TABLE genre_popularity_by_country AS
SELECT
  country,
  TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(REPLACE(REPLACE(REPLACE(artist_genres, '[', ''), ']', ''), '\'', ''), ',', n.n), ',', -1)) AS genre,
  ROUND(AVG(artist_popularity), 2) AS avg_artist_popularity,
  SUM(streams) AS total_streams,
  COUNT(*) AS track_count
FROM
  spotify_enriched
JOIN (
  SELECT a.N + b.N * 10 + 1 AS n
  FROM (SELECT 0 AS N UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 
        UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) a,
       (SELECT 0 AS N UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 
        UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) b
) n
ON CHAR_LENGTH(artist_genres) - CHAR_LENGTH(REPLACE(artist_genres, ',', '')) >= n.n - 1
WHERE artist_genres IS NOT NULL
  AND TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(REPLACE(REPLACE(REPLACE(artist_genres, '[', ''), ']', ''), '\'', ''), ',', n.n), ',', -1)) <> ''
GROUP BY country, genre;

-- 2 Finding which artists are popular in different countries--
CREATE TABLE global_artists_exports AS
SELECT
	main_artist,
	COUNT(DISTINCT country) AS num_countries,
    SUM(CAST(streams AS UNSIGNED)) AS total_streams
FROM spotify_enriched
GROUP BY main_artist
ORDER BY num_countries DESC;

-- Creating a continent column for the genre popularity --
ALTER TABLE genre_popularity_by_country
ADD COLUMN continent VARCHAR(100);

SET SQL_SAFE_UPDATES = 0;

UPDATE genre_popularity_by_country
SET continent = CASE
	WHEN country IN ('USA', 'Canada') THEN 'North America'
    WHEN country IN ('Nigeria', 'South Africa') THEN 'Africa'
    WHEN country IN ('UK', 'France') THEN 'Europe'
    WHEN country IN ('Brazil', 'Colombia') THEN 'South America'
    WHEN country IN ('India', 'South Korea') THEN 'Asia'
END;

SET SQL_SAFE_UPDATES = 1;

-- 3 Creating a table for genre popularity by continent --
DROP TABLE IF EXISTS genre_popularity_by_continent;

CREATE TABLE genre_popularity_by_continent AS
SELECT
	continent,
    genre,
    SUM(total_streams) AS total_contiental_streams,
    SUM(track_count) AS continental_track_count,
    ROUND(SUM(total_streams) / SUM(track_count),0) AS avg_streams_per_track
FROM genre_popularity_by_country
GROUP BY continent, genre;

-- 4 Creating Table to compare local vs global influence--
DROP TABLE IF EXISTS artist_country_streams;

CREATE TABLE artist_country_streams AS
SELECT
	main_artist,
    country,
    COUNT(DISTINCT track_name) AS num_tracks,
    SUM(streams) AS total_streams
FROM spotify_enriched
WHERE 
	main_artist IS NOT NULL AND main_artist <> ''
GROUP BY main_artist, country;

DROP TABLE IF EXISTS ranked_local_artists;

CREATE TEMPORARY TABLE ranked_local_artists AS
SELECT
  a.main_artist,
  a.country,
  a.total_streams,
  g.num_countries,
  g.total_streams AS global_streams,
  RANK() OVER (PARTITION BY a.country ORDER BY a.total_streams DESC) AS country_rank
FROM artist_country_streams a
JOIN global_artists_exports g
  ON a.main_artist = g.main_artist
WHERE g.num_countries = 1;

DROP TABLE IF EXISTS regional_superstars;

CREATE TABLE regional_superstars AS
SELECT *
FROM ranked_local_artists
WHERE country_rank <= 10;



    



