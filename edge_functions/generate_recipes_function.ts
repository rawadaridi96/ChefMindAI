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
    const { mode, search_query, filters, meal_type, allergies, mood, recipe_context, user_question, is_executive } = await req.json()
    const apiKey = Deno.env.get('GEMINI_API_KEY')
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')

    if (!apiKey) throw new Error('GEMINI_API_KEY not found')
    
    // Auth check
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) throw new Error('Missing Authorization header')

    // Determine Model based on Tier
    // Executive Chefs get the cutting-edge 2.5 Flash
    // Others get the previous high-speed version (2.0 Flash)
    const modelVersion = is_executive ? 'gemini-2.5-flash' : 'gemini-2.0-flash-exp';
    
    // --- MODE 3: CONSULT CHEF (Substitution Assistant) ---
    if (mode === 'consult_chef') {
       if (!user_question) throw new Error('Question required')
       
       const promptText = `You are a helpful culinary assistant.
       Context Recipe: ${recipe_context || "General Cooking"}
       
       User Question: "${user_question}"
       
       OUTPUT FORMAT:
       Return a strictly valid JSON object with the following structure:
       {
         "answer": "Your concise, helpful answer (max 2-3 sentences). Focus on substitutions, techniques, or equipment. CRITICAL: If a substitution requires adjusting other ingredients (e.g. 'add more liquid' when using coconut flour), YOU MUST MENTION THIS HERE.",
         "modification": {
            "type": "replace", // or "remove", optional
            "target_ingredient": "exact name of ingredient",
            "replacement_ingredient": "new ingredient name (only if replace, MUST BE Title Case, e.g. 'Oat Flour')"
         }
       }
       
       - "modification" block is OPTIONAL. Include it ONLY if the user request implies a change (swap, remove, etc.).
       - If no modification, set "modification" to null.
       
       Do not include markdown code blocks. Just the raw JSON.`


       // Use Gemini to answer
       const url = `https://generativelanguage.googleapis.com/v1beta/models/${modelVersion}:generateContent?key=${apiKey}`
       const response = await fetch(url, {
         method: 'POST',
         headers: { 'Content-Type': 'application/json' },
         body: JSON.stringify({ contents: [{ parts: [{ text: promptText }] }] })
       })
       
       if (!response.ok) {
           const errText = await response.text();
           console.error(`Gemini API Error (${modelVersion}):`, errText);
           throw new Error(`Gemini API Failed: ${errText}`);
       }
       
       const data = await response.json()
       const rawText = data.candidates?.[0]?.content?.parts?.[0]?.text || "{}"
       
       // Cleanup markdown if present
       const cleanedText = rawText.replace(/```json/g, '').replace(/```/g, '').trim()
       
       let parsedResponse = { answer: "I couldn't understand that.", modification: null }
       try {
          parsedResponse = JSON.parse(cleanedText)
       } catch (e) {
          // Fallback if LLM fails JSON
          parsedResponse.answer = rawText
       }
       
       return new Response(JSON.stringify(parsedResponse), {
         headers: { ...corsHeaders, 'Content-Type': 'application/json' },
       })
    }

    // --- RECIPE GENERATION MODES (Discover & Pantry Chef) ---
    
    // 1. ALWAYS Fetch Pantry Items (for cross-referencing or generation)
    if (!supabaseUrl || !supabaseAnonKey) {
       throw new Error('Supabase Configuration Missing')
    }

    const dbUrl = `${supabaseUrl}/rest/v1/pantry_items?select=name`
    const dbResponse = await fetch(dbUrl, {
      method: 'GET',
      headers: {
        'apikey': supabaseAnonKey,
        'Authorization': authHeader,
        'Content-Type': 'application/json'
      }
    })

    if (!dbResponse.ok) {
       const err = await dbResponse.text()
       throw new Error(`Failed to fetch pantry: ${err}`)
    }

    const items = await dbResponse.json()
    const pantryIngredients = items.map((i: any) => i.name)
    const pantryString = pantryIngredients.join(', ')

    let promptText = `You are a world-class chef. Create 3 unique recipes.`

    // Mode 1: Global Discovery
    if (mode === 'discover') {
      if (!search_query) throw new Error('Search query required for discovery mode')
      promptText += `\n\nUser Request: "${search_query}"`
      promptText += `\nCreate these recipes based on the user's request. Compare required ingredients against the user's pantry list below.`
    } 
    // Mode 2: Pantry Chef
    else if (mode === 'pantry_chef') {
      if (pantryIngredients.length === 0) {
        // Fallback behavior: Don't error, just suggest recipes based on filters
        promptText += `\n\nThe user's pantry is empty. Suggest 3 simple, accessible recipes fitting the Meal Type and Filters provided.`
      } else {
        promptText += `\n\nCreate recipes that primarily use the ingredients from the user's pantry list below.`
      }
    } else {
      throw new Error(`Invalid mode: ${mode}`)
    }

    // --- APPLY FILTERS & CONTEXT ---
    if (meal_type) {
        let cleanMealType = meal_type.trim();
        // Typos handling
        if (cleanMealType.toLowerCase() === 'launch') cleanMealType = 'Lunch';

        promptText += `\nTarget Meal Type: ${cleanMealType}`;
        
        // Strict Negative Constraints
        const lowerType = cleanMealType.toLowerCase();
        if (lowerType === 'lunch' || lowerType === 'dinner' || lowerType === 'main meal') {
             promptText += `\nCRITICAL: User specifically requested ${cleanMealType}. DO NOT PROVIDE DESSERTS, smoothies, or sweet snacks. Provide savory main courses only.`;
        } else if (lowerType === 'dessert') {
             promptText += `\nCRITICAL: User specifically requested Dessert. DO NOT PROVIDE SAVORY DISHES.`;
        }
    }
    if (filters && filters.length > 0) {
        promptText += `\nStyle/Dietary Filters: ${filters.join(', ')}`
    }
    if (allergies) {
        promptText += `\nSTRICT ALLERGIES/EXCLUSIONS: ${allergies}`
    }
    if (mood) {
        promptText += `\n\nUSER MOOD: ${mood}.
        The user is in a "${mood}" mood. Ensure the recipes align with this vibe.
        - Comfort: Hearty, warm, nostalgic.
        - Date Night: Impressive, romantic, plating-focused.
        - Quick & Easy: Minimal prep, fast cooking.
        - Energetic: Light, fresh, high protein/healthy fats.
        - Adventurous: Bold flavors, unique ingredients or combinations.
        - Fancy: Gourmet techniques, elegant presentation.`
    }

    // --- COMMON CONTEXT & FORMAT ---
    promptText += `\n\nUser's Pantry List: [${pantryString}]`
    promptText += `\n\nCRITICAL OUTPUT RULES:
    1. **STRICT RECIPES ONLY:** If the user's request is NOT related to cooking, food, or recipes (e.g., "write an essay", "math homework", "code"), you must REFUSE to generate the requested content. Instead, return a single recipe titled "Chef's Limitation" with the description "I am a Chef AI. I can only help you cook! Please ask me for a recipe." and empty ingredients/instructions.
    2. Return strictly valid JSON.
    3. For every ingredient, check if it exists (or is a close match) in the Pantry List. Set "is_missing" to true if NOT in pantry.
    4. Include detailed step-by-step instructions.
    5. List required kitchen equipment.
    6. Provide a macro breakdown (protein, carbs, fat).
    
    JSON Structure:
    {
      "recipes": [
        {
          "title": "Recipe Name",
          "description": "Brief description",
          "time": "15 mins",
          "calories": "350 kcal",
          "macros": { "protein": "25g", "carbs": "10g", "fat": "15g" },
           "ingredients": [
            { "name": "Ingredient Name", "amount": "quantity", "is_missing": true }
          ],
          "instructions": [
            "Step 1...",
            "Step 2..."
          ],
          "equipment": ["Oven", "Bowl", "Whisk"]
        }
      ]
    }
    Do not add markdown.`

    // Using configured model version
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${modelVersion}:generateContent?key=${apiKey}`
    
    // Retry logic for 503
    let response;
    let retries = 3;
    while (retries > 0) {
      try {
        response = await fetch(url, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ contents: [{ parts: [{ text: promptText }] }] })
        })

        if (response.status === 503) {
          console.log(`Model overloaded, retrying... (${retries} left)`)
          await new Promise(resolve => setTimeout(resolve, 1000));
          retries--;
          continue;
        }
        break;
      } catch (e) {
        console.error("Fetch error:", e);
        retries--;
        await new Promise(resolve => setTimeout(resolve, 1000));
      }
    }
    
    if (!response || !response.ok) {
        const errData = response ? await response.text() : "Unknown error"
        console.error(`Gemini API Failed (${modelVersion}):`, errData);
        throw new Error(`Google API Error: ${errData}`)
    }

    const data = await response.json()
    const candidate = data.candidates?.[0]
    if (!candidate) throw new Error("No candidates returned from Gemini")
    
    const text = candidate.content?.parts?.[0]?.text
    if (!text) throw new Error("No text returned from Gemini")
    
    // Aggressive cleanup
    const cleanedText = text.replace(/```json/g, '').replace(/```/g, '').trim()

    return new Response(cleanedText, {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })

  } catch (error) {
    console.error("Edge Function Error:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      // Use 400 so client libraries might read the body, though Flutter client might still throw generic FunctionException.
      // But at least logging is improved.
      status: 400, 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
