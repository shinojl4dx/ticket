from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
import boto3

app = FastAPI()

dynamodb = boto3.resource('dynamodb', region_name='ap-south-1')
table = dynamodb.Table('User_Ticket')

@app.post("/login")
async def login(request: Request):
    data = await request.json()
    username = data.get("username")
    password = data.get("password")

    if not username or not password:
        return JSONResponse({"status": "failure", "error": "Missing credentials"})

    try:
        response = table.get_item(Key={'User_Name': username})
        item = response.get("Item")
        if item and item.get("Password") == password:
            return JSONResponse({"status": "success"})
        else:
            return JSONResponse({"status": "failure"})
    except Exception as e:
        return JSONResponse({"status": "failure", "error": str(e)})

