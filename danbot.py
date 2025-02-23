""""Open AI example code"""

import os

# For Open AI, I'll alow you to use the OpenAI library in place of requests
from openai import OpenAI


# Read my API key from an environment variable
# ex: export MY_OPENAI_KEY=abcdefgthismyfakekey123
api_key = os.environ["MY_OPENAI_KEY"]

# Initialize the API client with my project, org, and API key
client = OpenAI(
    api_key=api_key,
    organization='org-oLSiLGf4uvhkmhyi3zUWtGGc',
    project='proj_OFRxxr9nwQzP0lGw2nwNBPmS'
)

user_content = input("What can I help you with today? \n")

# Make the API call to Open AI
completion = client.chat.completions.create(
    model="gpt-4o",
    messages=[
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": user_content}
    ]
)

# Print the output
print("")
print(completion.choices[0].message.content)
