# Databricks notebook source
# MAGIC %run ./config/configuration

# COMMAND ----------

# MAGIC %md
# MAGIC Handle Quarantined Records
# MAGIC \
# MAGIC Step 1: Load Quarantined Records from the Bronze Table

# COMMAND ----------

from pyspark.sql.functions import col
bronzeQuarantinedDF = spark.read.table("movie_bronze").filter(col("status") == "quarantined")

# COMMAND ----------

# MAGIC %md
# MAGIC Step 2: Transform the Quarantined Records

# COMMAND ----------

display(bronzeQuarantinedDF)

# COMMAND ----------

bronzeQuarTransDF = bronzeQuarantinedDF.select(col("value.*"))

# COMMAND ----------

# MAGIC %md
# MAGIC Step 3: Absolute the RunTime value

# COMMAND ----------

from pyspark.sql.functions import abs, when

repairDF = bronzeQuarTransDF.withColumn("RunTime", abs(col("RunTime"))).withColumn("Budget", when((bronzeQuarTransDF.Budget < 100000), 100000).otherwise(bronzeQuarTransDF.Budget))

# COMMAND ----------

display(repairDF)

# COMMAND ----------

# MAGIC %md
# MAGIC 
# MAGIC Batch Write the Repaired Records to the Silver Table

# COMMAND ----------

silverCleanedDF = repairDF.select(
    col("Id").cast("INTEGER"),
    col("Budget"),
    col("Revenue"),
    col("RunTime").cast("INTEGER"),
    col("Price"),
    col("Title"),
    col("Overview"),
    col("Tagline"),
    col("ImdbUrl"),
    col("TmdbUrl"),
    col("PosterUrl"),
    col("BackdropUrl"),
    col("ReleaseDate").cast("DATE"),
    col("CreatedDate").cast("DATE").alias("p_CreatedDate"),
    col("UpdatedDate"),
    col("UpdatedBy"),
    col("CreatedBy")
)
(
    silverCleanedDF.write.format("delta")
    .mode("append")
    .partitionBy("p_CreatedDate")
    .save(silverPath+"movie/")
)

# COMMAND ----------

from delta.tables import DeltaTable
from pyspark.sql.functions import lit
bronzeTable = DeltaTable.forPath(spark, bronzePath)
silverAugmented = silverCleanedDF.withColumn("status", lit("loaded"))

update_match = "bronze.value = clean.value"
update = {"status": "clean.status"}

(
    bronzeTable.alias("bronze")
    .merge(silverAugmented.alias("clean"), update_match)
    .whenMatchedUpdate(set=update)
    .execute()
)

# COMMAND ----------


