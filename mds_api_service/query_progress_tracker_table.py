import json
import os
import mysql.connector
from decimal import Decimal
from datetime import datetime
from dotenv import load_dotenv

class EnhancedEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)  # Convert Decimal to float
        if isinstance(obj, datetime):
            return obj.isoformat()  # Convert datetime to ISO 8601 string
        return super(EnhancedEncoder, self).default(obj)

def parse_json_fields(data):
    json_fields = ['investigators_name', 'repository_metadata', 'dmp_plan', 'heal_cde_used', 'vlmd_metadata']
    for field in json_fields:
        if field in data and isinstance(data[field], str):
            try:
                data[field] = json.loads(data[field].replace("'", "\""))  # Replace single quotes with double quotes
            except json.JSONDecodeError:
                pass  # If it fails, keep it as a string
    return data

load_dotenv()

# Accessing variables
db_username = os.getenv('DB_USER')
db_password = os.getenv('DB_PASSWORD')
db_host = os.getenv('DB_HOST')
db_database = os.getenv('DB_NAME')
table_name = os.getenv('TABLE_NAME')

def lambda_handler(event, context):
    appl_id = proj_num = hdp_id = ''
    results = []

    try:
        appl_id = event['queryStringParameters'].get('appl_id', '')
        proj_num = event['queryStringParameters'].get('proj_num', '')
        hdp_id = event['queryStringParameters'].get('hdp_id', '').upper()

        if appl_id.startswith('CTN'):
            normalized_appl_id = appl_id.replace('-', '')  # Remove dashes if CTN prefix is present
        else:
            normalized_appl_id = appl_id

        normalized_proj_num = proj_num.replace('-', '')  # Remove dashes from proj_num

        conn = mysql.connector.connect(
            user=db_username, 
            password=db_password, 
            host=db_host, 
            database=db_database
        )

        cursor = conn.cursor()

        # Sample query - modify as needed
        query = f"SELECT * FROM {table_name} WHERE REPLACE(appl_id, '-', '')=%s OR REPLACE(project_num, '-', '')=%s OR REPLACE(hdp_id, '-', '')=%s;"
        cursor.execute(query, (normalized_appl_id, normalized_proj_num, hdp_id))

        # Check if the cursor.description is not None
        if cursor.description is not None:
            columns = [column[0] for column in cursor.description]
            rows = cursor.fetchall()
            for row in rows:
                result = dict(zip(columns, row))
                result = parse_json_fields(result)
                results.append(result)
        else:
            results = "No results returned or query did not execute successfully."

        # Close the cursor and the connection
        cursor.close()
        conn.close()

    except mysql.connector.Error as e:
        results = f"Database error: {e}"
    except Exception as e:
        results = f"Execution error: {e}"

    return {
        'statusCode': 200,
        'headers': {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
        },
        'body': json.dumps(results, cls=EnhancedEncoder)
    }

# test = lambda_handler(0, 0)
# print(test)
