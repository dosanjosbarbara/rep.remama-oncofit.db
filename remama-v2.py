from supabase import create_client

url = "https://newpfoorzirsikneokan.supabase.co" ##
anon_key = "sb_publishable_P0sTq0xClHpaWRDyHmO5Fw_KFlAVGN2" ## 

supabase = create_client(url, anon_key)

# teste real de conexão - busca as primeiras linhas de uma tabela que já tem dado
response = supabase.table("status_participante").select("*").execute()
print(response.data)