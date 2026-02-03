import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { GoogleGenerativeAI } from "https://esm.sh/@google/generative-ai@0.21.0";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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
    // Using 2.0 Flash for everyone for stability/quality.
    const modelVersion = 'gemini-2.0-flash';

    // Artificial differentiation: Standard users wait a bit (Simulated Queue)
    if (!is_executive) {
       console.log("Standard Tier: Simulating processing queue...");
       await new Promise(resolve => setTimeout(resolve, 4000)); // 4s delay
    }
    
    // --- MODE 3: CONSULT CHEF (Substitution Assistant) ---
    if (mode === 'consult_chef') {
       if (!user_question) throw new Error('Question required')
       
       // Construct Context String
       let contextStr = "General Cooking";
       if (recipe_context) {
           if (typeof recipe_context === 'string') {
               contextStr = recipe_context;
           } else if (typeof recipe_context === 'object') {
               contextStr = `Title: ${recipe_context.title || 'Untitled'}\n`;
               if (recipe_context.ingredients) contextStr += `Ingredients: ${JSON.stringify(recipe_context.ingredients)}\n`;
               if (recipe_context.instructions) contextStr += `Instructions: ${JSON.stringify(recipe_context.instructions)}\n`;
           }
       }

       const promptText = `You are a helpful culinary assistant.
       Context Recipe: ${contextStr}
       
       User Question: "${user_question}"
       
       OUTPUT FORMAT:
       Return a strictly valid JSON object with the following structure:
       {
         "answer": "Your concise, helpful answer (max 2-3 sentences). Focus on substitutions, techniques, or equipment. CRITICAL: If a substitution requires adjusting other ingredients (e.g. 'add more liquid' when using coconut flour), explain why in this answer.",
         "modification": {
            "type": "replace", // or "remove"
            "target_ingredient": "exact name of ingredient to change",
            "replacement_ingredient": {
                "name": "new ingredient name (Title Case)",
                "amount": "adjusted amount (e.g. '3/4 cup')"
            } 
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
      promptText += `\nIMPORTANT: Generate recipes based SOLELY on the user's request. 
      - Do NOT attempt to match ingredients to any pantry. Assume the user has access to EVERYTHING.
      - AUTHENTICITY RULE: If the user names a specific dish (e.g. "Kabsa", "Carbonara"), you MUST provide at least one traditional/authentic version of that dish (e.g. Rice + Meat for Kabsa), rather than just "flavored" variations.`
    } 
    // Mode 2: Pantry Chef
    else if (mode === 'pantry_chef') {
      if (pantryIngredients.length === 0) {
        // Fallback behavior: Don't error, just suggest recipes based on filters
        promptText += `\n\nThe user's pantry is empty. Suggest 3 simple, accessible recipes fitting the Meal Type and Filters provided.`
      } else {
        promptText += `\n\nCreate recipes that use the ingredients from the user's pantry list below.
        CRITICAL CULINARY LOGIC:
        1. **SELECT A THEME FIRST**: Decide if the recipe is SAVORY or SWEET.
        2. **STRICT EXCLUSION**:
           - If SAVORY (e.g., Meat, Chicken, Pasta), YOU MUST IGNORE all sweet ingredients (Chocolate, Biscuits, Vanilla) unless used in a trivial authentic way (e.g. pinch of sugar in sauce).
           - If SWEET (e.g., Dessert), YOU MUST IGNORE all savory ingredients (Meat, Garlic, Onions).
        3. **DO NOT MIX** incompatible logical groups just to use more items. A simple Chicken Breast recipe is better than "Chicken with Chocolate Glaze".`
      }
    } else {
      throw new Error(`Invalid mode: ${mode}`)
    }

    // --- APPLY FILTERS & CONTEXT ---
    if (meal_type) {
        let cleanMealType = meal_type.trim();
        // Typos handling
        if (cleanMealType.toLowerCase() === 'launch') cleanMealType = 'Lunch';

        // Detect "Surprise Me" (in various languages if possible, but mainly English/fallback)
        const isSurprise = cleanMealType.toLowerCase().includes('surprise') || 
                          cleanMealType.toLowerCase().includes('sorpre') || 
                          cleanMealType.toLowerCase().includes('surpre');

        if (isSurprise) {
            promptText += `\nTarget Meal Type: CHEF'S CHOICE (Surprise the user).`;
            promptText += `\nCRITICAL: Create 3 distinct, high-quality recipes (e.g. One Breakfast, One Main Course, One Dessert OR 3 Unique Dinner ideas).`;
            promptText += `\nIMPORTANT: Ensure the recipes are COHESIVE and TASTY. Do NOT generate weird combinations just to be unique (e.g. avoid 'Chicken with Chocolate' unless it's a known authentic dish like Mole).`;
        } else {
            promptText += `\nTarget Meal Type: ${cleanMealType}`;
            
            // Strict Negative Constraints
            const lowerType = cleanMealType.toLowerCase();
            if (lowerType === 'lunch' || lowerType === 'dinner' || lowerType === 'main meal') {
                promptText += `\nCRITICAL: User specifically requested ${cleanMealType}. DO NOT PROVIDE DESSERTS, smoothies, or sweet snacks. Provide savory main courses only.`;
            } else if (lowerType === 'dessert') {
                promptText += `\nCRITICAL: User specifically requested Dessert. DO NOT PROVIDE SAVORY DISHES.`;
            }
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
    if (mode === 'pantry_chef') {
        promptText += `\n\nUser's Pantry List: [${pantryString}]`
        promptText += `\n\nCRITICAL OUTPUT RULES:
        1. **STRICTLY EDIBLE FOOD ONLY:** You are a CHEF.
        2. Return strictly valid JSON.
        3. **SMART PANTRY MATCHING:** Check each ingredient against the User's Pantry List. Only set "is_missing" to true if the user truly lacks the core ingredient.
        4. Include detailed step-by-step instructions.`
    } else {
        // DISCOVER MODE - NO PANTRY
        promptText += `\n\nCRITICAL OUTPUT RULES:
        1. **STRICTLY EDIBLE FOOD ONLY:** You are a CHEF.
        2. Return strictly valid JSON.
        3. Set "is_missing" to true for ALL ingredients (Client will handle matching).
        4. Include detailed step-by-step instructions.`
    }
    

    promptText += `
    5. List required kitchen equipment.
    6. Provide a macro breakdown (protein, carbs, fat).
    7. For every recipe, provide a "image_prompt" field. This should be a highly detailed, professional food photography prompt for an AI image generator (e.g., "Mouth-watering [Recipe Title], vibrant colors, garnishes, soft cinematic lighting, 8k, macro photography, wooden table background").
    
    JSON Structure:
    {
      "recipes": [
        {
          "title": "Recipe Name",
          "description": "Brief description",
          "time": "15 mins",
          "calories": "350 kcal",
          "macros": { "protein": "25g", "carbs": "10g", "fat": "15g" },
          "image_keywords": "Simple, high-level keywords for searching stock photos (e.g. 'Pancakes', 'Chicken Curry'). Avoid adjectives.",
          "image_prompt": "Detailed AI image prompt",
           "ingredients": [
            { 
              "name": "Ingredient Name", 
              "amount": "quantity", 
              "is_missing": true,
              "category": "Produce" // or "Dairy", "Meat", "Bakery", "Frozen", "Pantry", "Beverages", "Other"
            }
          ],
          "instructions": [
            "Step 1...",
            "Step 2..."
          ],
          "equipment": ["Oven", "Bowl", "Whisk"]
        }
      ]
    }
    
    CRITICAL: Valid Categories are: "Produce", "Meat", "Dairy", "Bakery", "Frozen", "Pantry", "Beverages", "Household", "Other". Auto-categorize ingredients intelligently.
    
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

    let finalData = cleanedText;
    try {
        const parsed = JSON.parse(cleanedText);
        if (parsed.recipes && Array.isArray(parsed.recipes)) {
            const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
            const supabase = (supabaseUrl && supabaseServiceKey) 
                ? createClient(supabaseUrl, supabaseServiceKey) 
                : null;

            // Image Sourcing via Pexels API
            const pexelsApiKey = Deno.env.get('PEXELS_API_KEY');

            if (pexelsApiKey) {
                 console.log(`Fetching images for ${parsed.recipes.length} recipes from Pexels...`);
                 const recipesWithImages = await Promise.all(parsed.recipes.map(async (r: any) => {
                     // Optimize Search: Clean the title and focus on key descriptive words
                     // Remove qualitative adjectives that might confuse search engine if too specific
                     // e.g. "Delicious Fluffy Vanilla Pancakes" -> "Vanilla Pancakes"
                     
                     // Strategy: 
                     // 1. Use the full title first, as it's usually the most descriptive (e.g. "Chicken Alfredo").
                     // 2. Append 'food' to context.
                     
                     let pexelsQuery = r.title;
                     
                     // Heuristic: If title is very long, maybe just use the first few words? 
                     // Or trust Pexels semantic search.
                     // Actually, "Chocolate Peanut Butter Protein Pancakes" (from user screenshot) failing to "cupcakes" is weird.
                     // It likely matched "Chocolate Peanut Butter" broad term.
                     
                     // Let's explicitly look for the END of the title which usually holds the noun (Pancakes, Chicken, Salad)
                     // But English isn't always like that.
                     // Better approach: Ask LLM to provide a "search_term" specifically for Pexels in the JSON.
                     // But to avoid changing the prompt structure too slightly, let's just stick to Title + "Dish"
                     // Or just strict Title.
                     
                     // Optimize Search: Use LLM provided keywords if available, otherwise fallback to title
                     if (r.image_keywords) {
                        pexelsQuery = r.image_keywords;
                     } // else uses title
                     
                     // "food" or "dish" suffix helps ground it in culinary results
                     // Use "food photography" to get high quality results
                     const imageUrl = await fetchPexelsImage(`${pexelsQuery} dish`, pexelsApiKey);
                     
                     return {
                         ...r,
                         thumbnail: imageUrl,
                         image: imageUrl, 
                         image_prompt: undefined, // Clean up
                         image_keywords: undefined
                     };
                 }));
                 parsed.recipes = recipesWithImages;
            } else {
                // Fallback: Remove images if no keys configured
                console.log('No Pexels API key found. Skipping image search.');
                parsed.recipes = parsed.recipes.map((r: any) => ({
                    ...r,
                    thumbnail: null,
                    image: null
                }));
            }
            finalData = JSON.stringify(parsed);
        }
    } catch (e: any) {
        console.error("Failed to parse recipes:", e);
    }

    return new Response(finalData, {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })

  } catch (error: any) {
    console.error("Edge Function Error:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      // Use 400 so client libraries might read the body, though Flutter client might still throw generic FunctionException.
      // But at least logging is improved.
      status: 400, 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})

async function fetchPexelsImage(query: string, apiKey: string): Promise<string | null> {
    try {
        console.log(`Searching Pexels for: ${query}`);
        // per_page=5 and pick random to avoid duplicates/always showing same result for similar queries
        const url = `https://api.pexels.com/v1/search?query=${encodeURIComponent(query)}&per_page=5&orientation=landscape`;
        
        const res = await fetch(url, {
            headers: {
                'Authorization': apiKey
            }
        });

        if (!res.ok) {
            console.error(`Pexels API Error: ${res.status} ${await res.text()}`);
            return null;
        }
        
        const data = await res.json();
        const photos = data.photos || [];
        
        if (photos.length > 0) {
            // Pick random one
            const randomIndex = Math.floor(Math.random() * photos.length);
            const photo = photos[randomIndex];
            // detailed: photo.src.medium or large
            return photo.src.large2x || photo.src.large || photo.src.medium;
        }
        return null;
    } catch (e) {
        console.error("Pexels search exception:", e);
        return null;
    }
}
