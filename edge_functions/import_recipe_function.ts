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
    const { url } = await req.json()
    const apiKey = Deno.env.get('GEMINI_API_KEY')

    if (!apiKey) throw new Error('GEMINI_API_KEY not found')
    if (!url) throw new Error('URL is required')

    console.log(`Processing URL: ${url}`)

    // 0. Pre-process URL
    // Convert YouTube Shorts to Watch URL for better metadata availability
    let targetUrl = url;
    if (url.includes('youtube.com/shorts/')) {
        targetUrl = url.replace('/shorts/', '/watch?v=');
        console.log(`Converted Shorts URL to: ${targetUrl}`);
    }

    // 1. Fetch the HTML content
    let htmlContent = ""
    try {
       const siteRes = await fetch(targetUrl, {
         headers: {
           // Use a real browser UA to avoid "old browser" pages from YouTube/Instagram
           'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
           'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
           'Accept-Language': 'en-US,en;q=0.5'
         }
       })
       if (!siteRes.ok) throw new Error(`Failed to fetch site: ${siteRes.status}`)
       htmlContent = await siteRes.text()
    } catch (fetchErr) {
       console.error("Fetch error:", fetchErr)
       throw new Error(`Could not download recipe from URL.`)
    }
    
    // Truncate HTML
    const truncatedHtml = htmlContent.substring(0, 500000) 

    // 2. Prompt Gemini to Extract Recipe
    const promptText = `
    You are a culinary data extractor. 
    Analyze the following HTML content from a recipe webpage or video page (like YouTube, Instagram, TikTok) and extract the recipe details into a strict JSON format.
    
    URL: ${targetUrl}
    
    HTML Content (Truncated):
    ${truncatedHtml}
    
    CRITICAL OUTPUT RULES:
    1. Return strictly valid JSON.
    2. DECODE ALL HTML ENTITIES in text (e.g., convert "&amp;" to "&", "&#x200e;" to "", etc.).
    3. JSON-LD Priority: Look for 'application/ld+json' scripts (schema.org/Recipe) and use them if available.
    4. VIDEO/SOCIAL MEDIA STRATEGY:
       - If this is a video (YouTube, Instagram, TikTok), the recipe is likely in the "description", "caption", or "og:description" meta tags.
       - IGNORE generic site navigation text. FOCUS on the main content area/description.
       - If ingredients are not explicitly listed in a standard format, YOU MUST INFER them from the narrative if possible.
       - If you see a list of items followed by quantities in text, parse them.
       - If the content is just a video title like "Best Pasta Ever" with NO description of ingredients, set "error": "No recipe details found in description".
    5. Clean Data:
       - Title: Remove emojis and clickbait words (e.g. "WATCH TILL END").
       - Ingredients: Standardize to object { "name": "...", "amount": "..." }. Use "1 unit" or "to taste" if amount is missing.
    6. Guess Macros if missing (Protein/Carbs/Fat).
    
    JSON Structure:
    {
       "title": "Recipe Name",
       "description": "Brief description",
       "time": "XX mins",
       "calories": "XXX kcal",
       "macros": { "protein": "XXg", "carbs": "XXg", "fat": "XXg" },
       "ingredients": [
          { "name": "Ingredient Name", "amount": "quantity" }
       ],
       "instructions": [ "Step 1...", "Step 2..." ],
       "equipment": ["Oven", "Pan"],
       "error": null
    }
    
    Do not include markdown. Just key-value pairs.
    `

    const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${apiKey}`
    const response = await fetch(geminiUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ contents: [{ parts: [{ text: promptText }] }] })
    })

    if (!response.ok) {
        throw new Error(`Gemini API Error: ${response.statusText}`)
    }

    const data = await response.json()
    const rawText = data.candidates?.[0]?.content?.parts?.[0]?.text || "{}"
    
    // Cleanup
    const cleanedText = rawText.replace(/```json/g, '').replace(/```/g, '').trim()
    
    let recipeData;
    try {
       recipeData = JSON.parse(cleanedText)
    } catch (e) {
       throw new Error("Failed to parse AI response into Recipe JSON")
    }

    return new Response(JSON.stringify({ recipe: recipeData }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
