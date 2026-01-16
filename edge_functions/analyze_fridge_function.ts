import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { image_path } = await req.json()
    if (!image_path) {
      throw new Error('Image path is required')
    }

    const apiKey = Deno.env.get('GEMINI_API_KEY')
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')
    const authHeader = req.headers.get('Authorization')

    if (!apiKey || !supabaseUrl || !supabaseAnonKey || !authHeader) {
      throw new Error('Missing configuration or authorization')
    }

    // 1. Download Image from Supabase Storage
    // The path usually comes as "scans/timestamp.jpg"
    const storageUrl = `${supabaseUrl}/storage/v1/object/public/images/${image_path}`
    
    // Note: If bucket is private, we'd need to sign a URL or use the API to download with auth header.
    // Assuming 'images' bucket is public for read or we use the service role/auth header to fetch.
    // Let's try fetching with the Auth header just in case.
    const imageResponse = await fetch(storageUrl, {
      headers: {
        'Authorization': authHeader
      }
    })

    if (!imageResponse.ok) {
       // Try without auth if it's public
       const publicRetry = await fetch(storageUrl)
       if (!publicRetry.ok) {
          throw new Error(`Failed to download image from Supabase: ${imageResponse.statusText}`)
       }
    }

    const imageBlob = await imageResponse.blob()
    const arrayBuffer = await imageBlob.arrayBuffer()
    const base64Image = btoa(String.fromCharCode(...new Uint8Array(arrayBuffer)))

    // 2. Call Gemini Vision
    const promptText = `Identify all food ingredients in this image. 
    Return a strictly valid JSON list of strings under the key "ingredients".
    Be specific (e.g. 'Red Onion', 'Baby Spinach', 'Almond Milk').
    Do not include non-food items.
    
    JSON Example:
    {
      "ingredients": ["Tomato", "Mozzarella", "Basil"]
    }
    Do not add markdown formatting.`

    const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${apiKey}`
    
    const requestBody = {
      contents: [{
        parts: [
          { text: promptText },
          {
            inline_data: {
              mime_type: "image/jpeg",
              data: base64Image
            }
          }
        ]
      }]
    }

    const geminiResponse = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(requestBody)
    })

    if (!geminiResponse.ok) {
      const errText = await geminiResponse.text()
      throw new Error(`Gemini API Error: ${errText}`)
    }

    const data = await geminiResponse.json()
    const text = data.candidates?.[0]?.content?.parts?.[0]?.text
    
    if (!text) throw new Error("No response from Gemini")

    const cleanedText = text.replace(/```json/g, '').replace(/```/g, '').trim()

    return new Response(cleanedText, {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
