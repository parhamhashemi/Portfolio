-- Getting familiar with the data
SELECT TOP 5 *
FROM PortfolioProjectCovid..CovidDeaths;

SELECT TOP 5 *
FROM PortfolioProjectCovid..CovidVaccinations;

--CovidDeaths Dataset

-- Now we select the desired columns
SELECT location, population, date, total_cases, new_cases, total_deaths
FROM PortfolioProjectCovid..CovidDeaths
ORDER BY location, date;

-- Death to Case Ratio, Total Cases and Total Deaths percentage of country's population, and deeath probability
SELECT location, date, total_cases, ROUND(total_cases / population * 100, 6) AS total_cases_percent, total_deaths, ROUND(CAST(total_deaths AS INT) / population * 100, 6) AS total_deaths_percent, ROUND(total_deaths / total_cases * 100, 2) AS death_probability_percent 
FROM PortfolioProjectCovid..CovidDeaths
ORDER BY location, date;

--Same info in a specific country (Canada for example)
SELECT location, date, total_cases, ROUND(total_cases / population * 100, 6) AS total_cases_percent, total_deaths, ROUND(CAST(total_deaths AS INT) / population * 100, 6) AS total_deaths_percent, ROUND(total_deaths / total_cases * 100, 2) AS death_to_case_percent 
FROM PortfolioProjectCovid..CovidDeaths
WHERE location = 'Canada'
ORDER BY date;

--Unique continent values
SELECT DISTINCT(continent)
FROM PortfolioProjectCovid..CovidDeaths

-- NOTE: We have Null Contintent that is better to be omited from the next queries 

-- Highest infection rate in each country in a single day
SELECT location, MAX(total_cases) AS highest_infection_number, ROUND(MAX(total_cases) / population * 100, 2) AS highest_infection_rate_percent
FROM PortfolioProjectCovid..CovidDeaths
WHERE continent != '' AND total_cases != ''
GROUP BY location, population
ORDER BY highest_infection_rate_percent DESC;

-- Countries with highest death count per population in a single day
SELECT location, MAX(CAST(total_deaths AS INT)) AS highest_death_count, ROUND(MAX(CAST(total_deaths AS INT)) / population * 100, 2) AS highest_death_rate_percent
FROM PortfolioProjectCovid..CovidDeaths
WHERE continent IS NOT NULL AND total_deaths IS NOT NULL
GROUP BY location, population
ORDER BY highest_death_rate_percent DESC;

-- Comparing the continents based on their case and death related stats
SELECT continent, ROUND(SUM(population) / 1000000000000, 2) as billion_residents , MAX(CAST(total_deaths AS INT)) AS highest_death_count, ROUND(MAX(CAST(total_deaths AS INT)) / SUM(population) * 100,7) AS highest_death_rate_percent
FROM PortfolioProjectCovid..CovidDeaths
WHERE continent != ''
GROUP BY continent
ORDER BY highest_death_rate_percent DESC;

-- Global daily stats
SELECT date, SUM(new_cases) AS global_new_cases, ROUND(SUM(new_cases) / SUM(population) * 100,6) AS global_new_cases_percent, SUM(CAST(new_deaths AS INT)) AS global_new_deaths, ROUND(SUM(CAST(new_deaths AS INT)) / SUM(population) * 100,6) AS global_new_deaths_percent, SUM(total_cases)  AS global_total_cases, SUM(CAST(total_deaths AS INT)) AS global_total_deaths, ROUND(SUM(CAST (new_deaths AS INT)) / SUM(new_cases) * 100,6) AS global_cases_death_percent
FROM PortfolioProjectCovid..CovidDeaths
WHERE continent != ''
GROUP BY date
ORDER BY date DESC;

--Global overall stats
SELECT SUM(new_cases) AS global_total_cases, SUM(CAST(new_deaths AS INT)) AS global_total_deaths, ROUND(SUM(CAST (new_deaths AS INT)) / SUM(new_cases) * 100,3) AS global_total_cases_death_percent
FROM PortfolioProjectCovid..CovidDeaths
WHERE continent != '';

--End of CovidDeaths Dataset

-- Join CovidDeaths and CovidVaccinations
SELECT TOP 5 * FROM PortfolioProjectCovid..CovidDeaths AS d
INNER JOIN PortfolioProjectCovid..CovidVaccinations AS v
ON d.location = v.location AND d.date = v.date;

-- Rolling total number of vaccinations around the globe 
SELECT d.date, d.location, new_vaccinations, SUM(CONVERT(BIGINT,new_vaccinations)) OVER (PARTITION BY d.location ORDER BY d.location, d.date) AS rolling_total_vaccinations
FROM PortfolioProjectCovid..CovidDeaths AS d
INNER JOIN PortfolioProjectCovid..CovidVaccinations AS v
ON d.location = v.location AND d.date = v.date
WHERE d.continent != ''
ORDER BY d.location, d.date;

-- Vaccination completition percentage in a single country (for example Canada) since the date vaccination started

--Temporary Table for easier calculations

DROP TABLE IF EXISTS VacInfo;
CREATE TABLE VacInfo (
date DATETIME,
location NVARCHAR(225),
population INT,
new_vaccination INT,
rolling_total_vaccinations FLOAT,
vaccination_ratio FLOAT)

INSERT INTO VacInfo (date, location, population, new_vaccination, rolling_total_vaccinations)
SELECT d.date, d.location, population, CONVERT(INT,new_vaccinations), SUM(CONVERT(BIGINT,new_vaccinations)) OVER (PARTITION BY d.location ORDER BY d.location, d.date)
FROM PortfolioProjectCovid..CovidDeaths AS d
INNER JOIN PortfolioProjectCovid..CovidVaccinations AS v
ON d.location = v.location AND d.date = v.date
WHERE d.continent != ''

UPDATE VacInfo
SET vaccination_ratio = vi.rolling_total_vaccinations / vi.population
FROM VacInfo AS vi
WHERE date = vi.date AND location = vi.location

SELECT date, location, population, new_vaccination, rolling_total_vaccinations, ROUND((vaccination_ratio - CONVERT(INT,vaccination_ratio)) * 100, 6) AS current_round_completion_percent, CASE  
WHEN vaccination_ratio <= 1 THEN '1st Round'
WHEN vaccination_ratio > 1 AND vaccination_ratio <= 2 THEN '2nd Round'
ELSE 'Booster Round'
END AS vaccinations_round
FROM VacInfo
WHERE date > (SELECT MIN(date)
FROM VacInfo
WHERE new_vaccination != '' AND location = 'Canada')
AND location = 'Canada'
ORDER BY location, date;

-- Stroring the final query in a view

--DROP VIEW IF EXISTS CanadaVaccinationRounds;
CREATE VIEW CanadaVaccinationRounds AS
SELECT date, location, population, new_vaccination, rolling_total_vaccinations, ROUND((vaccination_ratio - CONVERT(INT,vaccination_ratio)) * 100, 6) AS current_round_completion_percent, CASE  
WHEN vaccination_ratio <= 1 THEN '1st Round'
WHEN vaccination_ratio > 1 AND vaccination_ratio <= 2 THEN '2nd Round'
ELSE 'Booster Round'
END AS vaccinations_round
FROM VacInfo
WHERE date > (SELECT MIN(date)
FROM VacInfo
WHERE new_vaccination != '' AND location = 'Canada')
AND location = 'Canada';

-- Delete the previously created Temporary Table if you want
DROP TABLE IF EXISTS VacInfo;

-- Restore the view
SELECT * FROM CanadaVaccinationRounds
ORDER BY location, date;