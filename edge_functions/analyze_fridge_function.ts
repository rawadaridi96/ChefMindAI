import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { encode } from "https://deno.land/std@0.168.0/encoding/base64.ts"

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
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    
    console.log("Function started. Config check:", { 
      hasApiKey: !!apiKey, 
      hasUrl: !!supabaseUrl, 
      hasServiceKey: !!serviceRoleKey 
    })

    if (!apiKey || !supabaseUrl || !serviceRoleKey) {
      throw new Error('Missing configuration. Required: GEMINI_API_KEY, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY')
    }

    // Initialize Admin Client (Bypasses RLS)
    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey)

    // 1. Download Image from Supabase Storage
    console.log(`Downloading image: ${image_path}`)
    
    const { data: imageBlob, error: downloadError } = await supabaseAdmin
      .storage
      .from('images')
      .download(image_path)

    if (downloadError) {
       console.error("Download Error Details:", downloadError)
       throw new Error(`Failed to download image: ${downloadError.message}`)
    }

    if (!imageBlob) {
        throw new Error("Download succeeded but returned no data")
    }

    const arrayBuffer = await imageBlob.arrayBuffer()
    
    // FIX: Use Deno's standard base64 encoder.
    // The previous method `String.fromCharCode(...uint8Array)` caused a Stack Overflow on large images.
    const base64Image = encode(arrayBuffer)
    
    console.log(`Image prepared. Size: ${base64Image.length}`)

    // 2. Call Gemini Vision
    console.log("Calling Gemini 2.5-flash...")
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
      console.error("Gemini API Error:", errText)
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
    console.error("Function Handler Error:", error)
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
